import Foundation
import QuartzCore
#if os(iOS)
import Flutter
#else
import FlutterMacOS
import AppKit
#endif

final class MetalCurlBridge: NSObject, FlutterPlugin {
  private let registry: FlutterTextureRegistry
  private var activity: NSObjectProtocol?
  private var renderers: [Int64: MetalCurlRenderer] = [:]
  init(registry: FlutterTextureRegistry) { self.registry=registry }
  static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger=registrar.messenger(), textures=registrar.textures()
    #else
    let messenger=registrar.messenger, textures=registrar.textures
    #endif
    let instance=MetalCurlBridge(registry:textures)
    let channel=FlutterMethodChannel(name:"fbooks.page_curl/metal",binaryMessenger:messenger)
    registrar.addMethodCallDelegate(instance,channel:channel)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let receivedNative=Int64(CACurrentMediaTime()*1_000_000)
    let args=call.arguments as? [String: Any] ?? [:]
    if call.method=="clock" {
      result(["received_native_us":receivedNative,"sent_native_us":Int64(CACurrentMediaTime()*1_000_000)])
      return
    }
    if call.method=="create" {
      guard let source=args["source"] as? String else { result(FlutterError(code:"arguments",message:"Missing Metal source",details:nil));return }
      // 管线准备独立计时；不将动态库编译混入暖态 GPU 帧数据。
      DispatchQueue.global(qos:.userInitiated).async {
        do {
          let renderer=try MetalCurlRenderer(source:source)
          DispatchQueue.main.async {
            let id=self.registry.register(renderer)
            self.renderers[id]=renderer
            #if os(macOS)
            if args["keep_visible"] as? Bool == true {
              self.activity = ProcessInfo.processInfo.beginActivity(options:.userInitiated,reason:"Page curl measurement")
              for window in NSApp.windows where window.contentViewController is FlutterViewController {
                window.level = .floating
                window.orderFrontRegardless()
              }
            }
            #endif
            result(["id":id,"initialization_ms":renderer.initializationMS,"gpu":renderer.device.name])
          }
        } catch { DispatchQueue.main.async { result(FlutterError(code:"metal_init",message:error.localizedDescription,details:nil)) } }
      }
      return
    }
    guard let id=(args["id"] as? NSNumber)?.int64Value,let renderer=renderers[id] else {
      result(FlutterError(code:"texture",message:"Unknown Metal texture",details:nil));return
    }
    if call.method=="dispose" {
      renderer.close();registry.unregisterTexture(id);renderers.removeValue(forKey:id)
      #if os(macOS)
      if renderers.isEmpty {
        if let token = activity { ProcessInfo.processInfo.endActivity(token);activity=nil }
        for window in NSApp.windows where window.contentViewController is FlutterViewController { window.level = .normal }
      }
      #endif
      result(nil);return
    }
    renderer.work.async {
      do {
        switch call.method {
        case "pages":
          guard let faces=args["faces"] as? [[String: Any]],let w=args["width"] as? Int,let h=args["height"] as? Int,w>0,h>0 else { throw NSError(domain:"MetalCurl",code:6) }
          try renderer.upload(faces,width:w,height:h)
          DispatchQueue.main.async { result(nil) }
        case "render":
          renderer.render(args,publish:{ if self.renderers[id] === renderer { self.registry.textureFrameAvailable(id) } },reply:result)
        case "metrics":
          let metrics=renderer.metrics(reset:args["reset"] as? Bool ?? false)
          DispatchQueue.main.async {
            var values=metrics
            values["thermal_state"]=ProcessInfo.processInfo.thermalState.rawValue
            #if os(macOS)
            let window=NSApp.windows.first(where: { $0.contentViewController is FlutterViewController })
            values["window_visible"]=window?.isVisible ?? false
            values["window_unoccluded"]=window?.occlusionState.contains(.visible) ?? false
            values["window_minimized"]=window?.isMiniaturized ?? false
            values["application_active"]=NSApp.isActive
            values["screen_maximum_fps"]=window?.screen?.maximumFramesPerSecond ?? 0
            #endif
            result(values)
          }
        case "snapshot":
          let snapshot=renderer.snapshot()
          DispatchQueue.main.async { result(snapshot) }
        default: DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
        }
      } catch { DispatchQueue.main.async { result(FlutterError(code:"metal",message:error.localizedDescription,details:nil)) } }
    }
  }
}
