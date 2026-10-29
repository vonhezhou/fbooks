import Foundation
import Metal
import MetalPerformanceShaders
import CoreVideo
import QuartzCore
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

private struct CurlUniforms {
  var shape: SIMD4<Float>
  var options: SIMD4<Float>
}

// 仅独立原型使用；图像经 CVPixelBuffer 交给 Flutter，几何与遮挡在 GPU 执行。
final class MetalCurlRenderer: NSObject, FlutterTexture {
  let device: MTLDevice
  let work = DispatchQueue(label: "page-curl.metal")
  private let commands: MTLCommandQueue
  private let pipeline: MTLRenderPipelineState
  private let shadowPipeline: MTLRenderPipelineState
  private let contactPipeline: MTLRenderPipelineState
  private let depthState: MTLDepthStencilState
  private let shadowDepthState: MTLDepthStencilState
  private let overlayDepthState: MTLDepthStencilState
  private let grid: MTLBuffer
  private let indices: MTLBuffer
  private let quad: MTLBuffer
  private let quadIndices: MTLBuffer
  private let contact: MTLBuffer
  private let contactIndices: MTLBuffer
  private let sampler: MTLSamplerState
  private let lock = NSLock()
  private var textureCache: CVMetalTextureCache!
  private var pool: CVPixelBufferPool?
  private var depth: MTLTexture?
  private var msaa: MTLTexture?
  private var shadow: MTLTexture?
  private var blurred: MTLTexture?
  private var shadowDepth: MTLTexture?
  private var blurFilters: [Int: MPSImageGaussianBlur] = [:]
  private var pages: [MTLTexture] = []
  private var width = 0, height = 0
  private var latest: CVPixelBuffer?
  private var latestSequence: Int64 = 0
  private var readyAt: Double = 0
  private var closed = false
  private var copied: Int64 = -1
  private var version = 0
  private var outputBuffers = Set<UInt>()
  private var readyCopies: [[String: Any]] = []
  private var samples: [[String: Any]] = []
  private var rejected = 0, copyCalls = 0, inFlight = 0
  let initializationMS: Double
  let samplesPerPixel = 4

  init(source: String) throws {
    let start = CACurrentMediaTime()
    guard let gpu = MTLCreateSystemDefaultDevice(), let queue = gpu.makeCommandQueue() else {
      throw NSError(domain: "MetalCurl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal unavailable"])
    }
    device = gpu; commands = queue
    let library = try gpu.makeLibrary(source: source, options: nil)
    func makePipeline(vertex: String, fragment: String, count: Int) throws -> MTLRenderPipelineState {
      let descriptor = MTLRenderPipelineDescriptor()
      descriptor.vertexFunction = library.makeFunction(name: vertex)
      descriptor.fragmentFunction = library.makeFunction(name: fragment)
      descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
      descriptor.depthAttachmentPixelFormat = .depth32Float
      descriptor.rasterSampleCount = count
      let color = descriptor.colorAttachments[0]!
      color.isBlendingEnabled = true
      color.sourceRGBBlendFactor = .one; color.destinationRGBBlendFactor = .oneMinusSourceAlpha
      color.sourceAlphaBlendFactor = .one; color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
      return try gpu.makeRenderPipelineState(descriptor: descriptor)
    }
    pipeline = try makePipeline(vertex: "curlVertex", fragment: "curlFragment", count: 4)
    shadowPipeline = try makePipeline(vertex: "curlVertex", fragment: "curlFragment", count: 1)
    contactPipeline = try makePipeline(vertex: "contactVertex", fragment: "contactFragment", count: 4)
    func makeDepth(_ compare: MTLCompareFunction, _ write: Bool) -> MTLDepthStencilState {
      let d = MTLDepthStencilDescriptor(); d.depthCompareFunction = compare; d.isDepthWriteEnabled = write
      return gpu.makeDepthStencilState(descriptor: d)!
    }
    depthState = makeDepth(.lessEqual, true)
    shadowDepthState = makeDepth(.less, true)
    overlayDepthState = makeDepth(.always, false)
    var vertices: [SIMD2<Float>] = [], triangles: [UInt16] = []
    for row in 0...24 { for col in 0...96 { vertices.append(SIMD2(Float(col)/96, Float(row)/24)) } }
    for row in 0..<24 { for col in 0..<96 {
      let a = UInt16(row*97+col); triangles += [a,a+1,a+97,a+1,a+98,a+97]
    } }
    grid = gpu.makeBuffer(bytes: vertices, length: vertices.count*8)!
    indices = gpu.makeBuffer(bytes: triangles, length: triangles.count*2)!
    let q: [SIMD2<Float>] = [SIMD2(0,0),SIMD2(1,0),SIMD2(0,1),SIMD2(1,1)]
    let qi: [UInt16] = [0,1,2,1,3,2]
    quad = gpu.makeBuffer(bytes: q, length: 32)!; quadIndices = gpu.makeBuffer(bytes: qi, length: 12)!
    var cv: [SIMD2<Float>] = [], ci: [UInt16] = []
    for row in 0...24 { cv += [SIMD2(0,Float(row)/24),SIMD2(1,Float(row)/24)] }
    for row in 0..<24 { let a = UInt16(row*2); ci += [a,a+1,a+2,a+1,a+3,a+2] }
    contact = gpu.makeBuffer(bytes: cv, length: cv.count*8)!
    contactIndices = gpu.makeBuffer(bytes: ci, length: ci.count*2)!
    let sampling = MTLSamplerDescriptor(); sampling.minFilter = .linear; sampling.magFilter = .linear
    sampling.sAddressMode = .clampToEdge; sampling.tAddressMode = .clampToEdge
    sampler = gpu.makeSamplerState(descriptor: sampling)!
    initializationMS = (CACurrentMediaTime()-start)*1000
    super.init()
    let status = CVMetalTextureCacheCreate(nil, nil, gpu, nil, &textureCache)
    guard status == kCVReturnSuccess else { throw NSError(domain: "MetalCurl", code: Int(status)) }
  }

  func upload(_ faces: [[String: Any]], width: Int, height: Int) throws {
    var textures: [MTLTexture] = []
    for face in faces {
      guard let w = face["width"] as? Int, let h = face["height"] as? Int,
            let bytes = face["rgba"] as? FlutterStandardTypedData, bytes.data.count == w*h*4 else {
        throw NSError(domain: "MetalCurl", code: 2)
      }
      let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: false)
      d.usage = .shaderRead; d.storageMode = .shared
      guard let texture = device.makeTexture(descriptor: d) else { throw NSError(domain: "MetalCurl", code: 3) }
      bytes.data.withUnsafeBytes { b in texture.replace(region: MTLRegionMake2D(0,0,w,h), mipmapLevel: 0, withBytes: b.baseAddress!, bytesPerRow: w*4) }
      textures.append(texture)
    }
    guard textures.count == 2 || textures.count == 4 else { throw NSError(domain: "MetalCurl", code: 4) }
    pages = textures; lock.lock(); version += 1; lock.unlock()
    if self.width == width && self.height == height { return }
    self.width = width; self.height = height
    let attrs: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String:width,kCVPixelBufferHeightKey as String:height,
      kCVPixelBufferMetalCompatibilityKey as String:true,kCVPixelBufferIOSurfacePropertiesKey as String:[:]]
    var created: CVPixelBufferPool?
    let status = CVPixelBufferPoolCreate(nil, [kCVPixelBufferPoolMinimumBufferCountKey as String:3] as CFDictionary, attrs as CFDictionary, &created)
    guard status == kCVReturnSuccess else { throw NSError(domain: "MetalCurl", code: Int(status)) }
    pool = created; outputBuffers.removeAll()
    func texture(_ format: MTLPixelFormat, _ w: Int, _ h: Int, _ count: Int) -> MTLTexture? {
      let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: w, height: h, mipmapped: false)
      d.usage = [.renderTarget,.shaderRead,.shaderWrite]; d.storageMode = .private; d.sampleCount = count
      if count>1 { d.textureType = .type2DMultisample; d.usage = .renderTarget }
      if format == .depth32Float { d.usage = .renderTarget }
      // Apple GPU 的 MSAA 与深度只在当前 render pass 内使用，避免外部内存常驻。
      if device.supportsFamily(.apple1) && (count>1 || format == .depth32Float) {
        d.storageMode = .memoryless
      }
      return device.makeTexture(descriptor: d)
    }
    depth = texture(.depth32Float,width,height,4); msaa = texture(.bgra8Unorm,width,height,4)
    shadow = texture(.bgra8Unorm,max(1,width/2),max(1,height/2),1)
    blurred = texture(.bgra8Unorm,max(1,width/2),max(1,height/2),1)
    shadowDepth = texture(.depth32Float,max(1,width/2),max(1,height/2),1)
    guard depth != nil, msaa != nil, shadow != nil, blurred != nil, shadowDepth != nil else { throw NSError(domain: "MetalCurl", code: 5) }
  }

  func render(_ arguments: [String: Any], publish: @escaping () -> Void, reply: @escaping FlutterResult) {
    let start = CACurrentMediaTime()
    guard let shape = arguments["shape"] as? [Double], shape.count == 4,
          let options = arguments["options"] as? [Double], options.count == 2,
          let sequence = (arguments["sequence"] as? NSNumber)?.int64Value, let pool = pool, pages.count >= 2 else {
      DispatchQueue.main.async { reply(FlutterError(code:"arguments",message:"Invalid render state",details:nil)) }; return
    }
    var buffer: CVPixelBuffer?
    let status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil,pool,[kCVPixelBufferPoolAllocationThresholdKey as String:5] as CFDictionary,&buffer)
    guard status == kCVReturnSuccess, let pixelBuffer = buffer, inFlight < 2 else {
      rejected += 1; DispatchQueue.main.async { reply(["accepted":false]) }; return
    }
    outputBuffers.insert(UInt(bitPattern: Unmanaged.passUnretained(pixelBuffer).toOpaque()))
    var wrapped: CVMetalTexture?
    let outputStatus = CVMetalTextureCacheCreateTextureFromImage(nil,textureCache,pixelBuffer,
      [kCVMetalTextureUsage as String:MTLTextureUsage.renderTarget.rawValue|MTLTextureUsage.shaderRead.rawValue] as CFDictionary,.bgra8Unorm,width,height,0,&wrapped)
    guard outputStatus == kCVReturnSuccess, let wrapped = wrapped, let output = CVMetalTextureGetTexture(wrapped), let command = commands.makeCommandBuffer() else {
      DispatchQueue.main.async { reply(FlutterError(code:"buffer",message:"Metal output allocation failed",details:nil)) }; return
    }
    let frameVersion = version
    let publishFrame = arguments["publish"] as? Bool ?? true
    let t = Float(shape[2]), wave = sin(Float.pi*t)
    let lift = Float(shape[0])*0.21*pow(max(0,wave),0.6)
    let fade = min(1,max(0,lift/3)), opacity = fade*fade*(3-2*fade)
    var u = CurlUniforms(shape: SIMD4(Float(shape[0]),Float(shape[1]),t,Float(shape[3])), options: SIMD4(Float(options[0]),Float(options[1]),0,opacity))
    let spread = options[0]>0.5
    func draw(_ encoder: MTLRenderCommandEncoder, _ pass: Float, _ front: MTLTexture, _ back: MTLTexture, _ curved: Bool) {
      u.options.z = pass
      encoder.setVertexBuffer(curved ? grid : quad, offset: 0, index: 0)
      encoder.setVertexBytes(&u,length:MemoryLayout<CurlUniforms>.stride,index:1)
      encoder.setFragmentBytes(&u,length:MemoryLayout<CurlUniforms>.stride,index:0)
      encoder.setFragmentTexture(front,index:0);encoder.setFragmentTexture(back,index:1)
      encoder.setFragmentSamplerState(sampler,index:0)
      encoder.drawIndexedPrimitives(type:.triangle,indexCount:curved ? 96*24*6 : 6,indexType:.uint16,indexBuffer:curved ? indices : quadIndices,indexBufferOffset:0)
    }
    let mask = MTLRenderPassDescriptor(); mask.colorAttachments[0].texture=shadow
    mask.colorAttachments[0].loadAction = .clear; mask.colorAttachments[0].storeAction = .store
    mask.colorAttachments[0].clearColor = MTLClearColor(red:0,green:0,blue:0,alpha:0)
    mask.depthAttachment.texture=shadowDepth; mask.depthAttachment.loadAction = .clear; mask.depthAttachment.storeAction = .dontCare; mask.depthAttachment.clearDepth=1
    let shadowEncoder=command.makeRenderCommandEncoder(descriptor:mask)!
    shadowEncoder.setRenderPipelineState(shadowPipeline);shadowEncoder.setDepthStencilState(shadowDepthState);shadowEncoder.setCullMode(.none)
    if t>0 && t<1 { draw(shadowEncoder,3,pages[0],pages[0],true) }
    shadowEncoder.endEncoding()
    let sigma=max(0.5,(1.5+lift*0.12)*Float(width)/Float(shape[0]*(spread ? 2:1))*0.5)
    let key=Int((sigma*2).rounded())
    let filter=blurFilters[key] ?? MPSImageGaussianBlur(device:device,sigma:Float(key)/2)
    filter.edgeMode = .zero;blurFilters[key]=filter
    filter.encode(commandBuffer:command,sourceTexture:shadow!,destinationTexture:blurred!)
    let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=msaa
    pass.colorAttachments[0].resolveTexture=output;pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .multisampleResolve
    pass.colorAttachments[0].clearColor=MTLClearColor(red:0,green:0,blue:0,alpha:0)
    pass.depthAttachment.texture=depth;pass.depthAttachment.loadAction = .clear;pass.depthAttachment.storeAction = .dontCare;pass.depthAttachment.clearDepth=1
    let encoder=command.makeRenderCommandEncoder(descriptor:pass)!
    encoder.setRenderPipelineState(pipeline);encoder.setDepthStencilState(depthState);encoder.setCullMode(.none)
    encoder.setFrontFacing(options[1]>0.5 ? .counterClockwise : .clockwise)
    if spread { draw(encoder,1,pages[0],pages[0],false) }
    draw(encoder,2,pages[spread ? 3:1],pages[0],false)
    encoder.setDepthStencilState(overlayDepthState);draw(encoder,4,blurred!,blurred!,false)
    if t>0 && t<1 {
      encoder.setRenderPipelineState(contactPipeline)
      u.options.z=6;encoder.setVertexBytes(&u,length:MemoryLayout<CurlUniforms>.stride,index:1)
      encoder.setVertexBuffer(contact,offset:0,index:0)
      encoder.drawIndexedPrimitives(type:.triangle,indexCount:24*6,indexType:.uint16,indexBuffer:contactIndices,indexBufferOffset:0)
    }
    encoder.setRenderPipelineState(pipeline);encoder.setDepthStencilState(depthState)
    draw(encoder,0,pages[spread ? 1:0],pages[spread ? 2:0],true)
    if spread { encoder.setDepthStencilState(overlayDepthState);draw(encoder,5,pages[0],pages[0],false) }
    encoder.endEncoding()
    let encodedMS=(CACurrentMediaTime()-start)*1000
    inFlight += 1
    command.addCompletedHandler { [self, wrapped] completed in
      _ = wrapped
      work.async { self.inFlight -= 1 }
      let ready=CACurrentMediaTime(),gpuMS=max(0,(completed.gpuEndTime-completed.gpuStartTime)*1000)
      lock.lock()
      let valid = !closed && frameVersion==version && completed.status == .completed
      if valid {
        if publishFrame { latest=pixelBuffer;latestSequence=sequence;readyAt=ready }
        if samples.count<6000 { samples.append(["sequence":sequence,"gpu_ms":gpuMS,"native_encode_ms":encodedMS,"native_ready_ms":(ready-start)*1000,"progress":shape[2]]) }
      }
      lock.unlock()
      DispatchQueue.main.async {
        if valid { if publishFrame { publish() };reply(["accepted":true,"sequence":sequence,"gpu_ms":gpuMS]) }
        else { reply(FlutterError(code:"render",message:"Metal command failed or stale",details:completed.error?.localizedDescription)) }
      }
    }
    command.commit()
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    lock.lock();defer { lock.unlock() }
    guard !closed, let buffer=latest else { return nil }
    copyCalls += 1
    if copied != latestSequence && readyCopies.count<6000 {
      let copiedAt=CACurrentMediaTime()
      readyCopies.append(["sequence":latestSequence,"native_copy_us":Int64(copiedAt*1_000_000),"ready_to_first_copy_ms":(copiedAt-readyAt)*1000])
      copied=latestSequence
    }
    return Unmanaged.passRetained(buffer)
  }

  func metrics(reset: Bool) -> [String: Any] {
    lock.lock();defer { lock.unlock() }
    let ownTextures=pages.reduce(0) { $0+$1.allocatedSize } +
      [depth,msaa,shadow,blurred,shadowDepth].compactMap { $0 }.reduce(0) { $0+$1.allocatedSize } + width*height*4*5
    let result: [String: Any] = ["gpu":device.name,"initialization_ms":initializationMS,"samples":samples,"first_copies":readyCopies,"copy_calls":copyCalls,"rejected":rejected,"output_buffer_objects_observed":outputBuffers.count,"output_pool_allocation_limit":5,"estimated_owned_texture_bytes":ownTextures,"memory_estimate":"conservative pool maximum; observed CVPixelBuffer wrapper count is not live buffer count","metal_device_allocated_bytes":device.currentAllocatedSize,"width":width,"height":height,"msaa":4,"last_sequence":latestSequence,"memoryless_attachments":device.supportsFamily(.apple1),"depth_test":true,"columns":96,"rows":24]
    if reset { samples.removeAll(keepingCapacity:true);readyCopies.removeAll(keepingCapacity:true);copyCalls=0;rejected=0;copied = -1 }
    return result
  }

  func snapshot() -> [String: Any]? {
    lock.lock();defer { lock.unlock() }
    guard let image=latest else { return nil }
    CVPixelBufferLockBaseAddress(image,.readOnly);defer { CVPixelBufferUnlockBaseAddress(image,.readOnly) }
    let stride=CVPixelBufferGetBytesPerRow(image),w=CVPixelBufferGetWidth(image),h=CVPixelBufferGetHeight(image)
    return ["width":w,"height":h,"stride":stride,"bgra":FlutterStandardTypedData(bytes:Data(bytes:CVPixelBufferGetBaseAddress(image)!,count:stride*h)),"sequence":latestSequence]
  }
  func close() { lock.lock();closed=true;latest=nil;lock.unlock() }
}
