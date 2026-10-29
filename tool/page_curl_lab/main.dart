import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'package:fbooks/l10n/app_localizations.dart';

import 'real_page_source.dart';
import 'curl_geometry.dart';
import 'curl_drag.dart';
import 'curl_motion.dart';
import 'curl_painter.dart';
import 'curl_shader_painter.dart';
import 'page_sources.dart';
import 'page_texture_cache.dart';
import 'input_latency.dart';
import 'metal_curl.dart';
import 'renderer_selection.dart';

const renderer = String.fromEnvironment('CURL_RENDERER', defaultValue: 'auto');

const shaderWarmup = bool.fromEnvironment(
  'CURL_SHADER_WARMUP',
  defaultValue: true,
);

const meshWarmup = bool.fromEnvironment('CURL_MESH_WARMUP', defaultValue: true);
const benchmark = bool.fromEnvironment('CURL_BENCH');
const output = String.fromEnvironment('CURL_OUTPUT', defaultValue: '');
const capture = bool.fromEnvironment('CURL_CAPTURE', defaultValue: true);
const inputSession = bool.fromEnvironment('CURL_INPUT_SESSION');
const simulated = bool.fromEnvironment('CURL_SIMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (benchmark) {
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
      exit(1);
    };
  }
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    await windowManager.setSize(const Size(1320, 900));
    await windowManager.setTitle('Fbooks — Page curl performance lab');
    if (Platform.isMacOS &&
        (benchmark ||
            const bool.fromEnvironment('CURL_KEEP_VISIBLE') ||
            const bool.fromEnvironment('CURL_METAL_KEEP_VISIBLE'))) {
      await windowManager.setAlwaysOnTop(true);
    }
    await windowManager.show();
    await windowManager.focus();
  }
  if (!const [
    'auto',
    'mesh',
    'shader',
    'compare',
    'metal',
    'metal-compare',
  ].contains(renderer)) {
    throw ArgumentError('Unknown CURL_RENDERER: $renderer');
  }
  final program = renderer == 'shader' || renderer == 'compare'
      ? await ui.FragmentProgram.fromAsset(curlShaderAsset)
      : null;
  // 模拟器只读取独立测试 App 的 Documents，不把个人书籍路径编入代码。
  final documents = const bool.fromEnvironment('CURL_INPUT_DOCUMENTS')
      ? await getApplicationDocumentsDirectory()
      : null;
  final realSource = RealPageSource(
    paths: documents == null
        ? RealPageSource.configuredPaths
        : {
            for (final kind in PageKind.values)
              kind:
                  '${documents.path}/input.${switch (kind) {
                    PageKind.text => 'epub',
                    PageKind.comic => 'cbz',
                    PageKind.pdf => 'pdf',
                  }}',
          },
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RealPageHost(
        source: realSource,
        child: CurlLab(program: program, realSource: realSource),
      ),
    ),
  );
}

class CurlLab extends StatefulWidget {
  const CurlLab({super.key, this.program, this.realSource, this.loadShader});
  final RealPageSource? realSource;
  final ui.FragmentProgram? program;
  final Future<ui.FragmentProgram> Function()? loadShader;
  @override
  State<CurlLab> createState() => _CurlLabState();
}

class _CurlLabState extends State<CurlLab> with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final _boundary = GlobalKey();
  late final _mesh = CurlMesh();
  ui.FragmentShader? _shader;
  Future<Duration>? _meshWarmup;
  Duration? _meshWarmupDuration;
  Future<Duration>? _shaderWarmup;
  Duration? _shaderWarmupDuration;
  final MetalCurlController? _metal = renderer.startsWith('metal')
      ? MetalCurlController()
      : null;
  CurlRendererChoice _rendererChoice = CurlRendererChoice.automatic;
  bool _useMetal = renderer == 'metal';
  bool _useShader = renderer == 'shader';
  String get _activeRenderer => _useMetal
      ? 'metal'
      : _useShader
      ? 'shader'
      : 'mesh';
  final _viewportReady = Completer<Size>();
  final _inputStarted = Completer<void>();
  final _captureDone = Completer<void>();
  final _frames = <ui.FrameTiming>[];
  final _input = InputLatencyProbe();
  InputLatencyProbe _renderRequests = InputLatencyProbe();
  int get _faceCount => _spread ? 4 : 2;
  Map<String, Object> _initialPreparation = {};
  PageTextureCache? _cache;
  Size _availableSize = const Size(390, 600);
  int _pageStart = 0;
  int get _lastPage => widget.realSource?.has(_kind) == true
      ? math.max(0, widget.realSource!.pageCount - 1)
      : 20;
  bool _turning = false;
  bool _settling = false;
  bool _backWindowReady = true;
  int _turnToken = 0;
  CurlDragPose? _continuingPose;
  Offset _continuingPointer = Offset.zero;
  Offset _latestPoint = Offset.zero;
  double _controlX = 0;
  final _motionTracker = CurlMotionTracker();
  CurlReleaseMotion? _releaseMotion;
  Duration? _latestPoseStamp, _releaseStamp;

  CurlDragPose get _currentPose => CurlDragPose(
    _animation.value,
    _grabY,
    _tilt ?? 0,
    _cornerWeight ?? curlCornerWeightForGrab(_grabY),
    _controlX,
    _horizontalWeight,
    _diagonalWeight,
    _cornerLimit,
  );

  void _onReleaseTick() {
    final release = _releaseMotion;
    if (!_settling || release == null) return;
    final t = (_animation.lastElapsedDuration?.inMicroseconds ?? 0) / 1000000;
    final pose = release.poseAt(t);
    _grabY = pose.grabY;
    _tilt = pose.tilt;
    _cornerWeight = pose.cornerWeight;
    _horizontalWeight = pose.horizontalWeight;
    _diagonalWeight = pose.diagonalWeight;
    _cornerLimit = pose.cornerLimit;
    _controlX = pose.controlX;
  }

  bool _gestureActive = false;
  int _gestureDirection = 0;
  int _gestureAnchor = 0;
  double _latestDelta = 0;
  Future<void> _gestureReady = Future.value();
  Object? _gestureError;
  PageTextures? _textures;
  PageKind _kind = PageKind.values.byName(
    const String.fromEnvironment('CURL_PAGE_KIND', defaultValue: 'text'),
  );
  Size _size = const Size(820, 700);
  double _requestedDpr = 2;
  double _dpr = 2;
  bool _spread = true;
  bool _rtl = false;
  bool _busy = true;
  double _grabY = 0.8;
  // 实书纹理采用白纸；合成测试页保留原有米色，纸背随页面来源保持一致。
  Color get _paperColor => widget.realSource?.has(_kind) == true
      ? Colors.white
      : const Color(0xfffaf6ec);
  String _status = 'Preparing textures…';
  String? _error;
  String? _rendererError;
  int? _firstVsync;
  int? _lastVsync;
  double _dragStart = 0;
  double _startProgress = 0;
  Offset _pointerDown = Offset.zero;
  Offset _dragOrigin = Offset.zero;
  double? _tilt;
  double? _cornerWeight;
  double _horizontalWeight = 0;
  double _diagonalWeight = 0;
  double _cornerLimit = 0;
  bool _gestureIntentPending = false;
  double _gestureIntentSlop = 0;

  @override
  void initState() {
    super.initState();
    _shader = widget.program?.fragmentShader();
    if (renderer == 'auto') {
      _useShader =
          defaultCurlBackend(defaultTargetPlatform) == CurlBackend.shader;
    }
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      animationBehavior: benchmark
          ? AnimationBehavior.preserve
          : AnimationBehavior.normal,
    );
    _animation.addListener(_onReleaseTick);
    WidgetsBinding.instance.addTimingsCallback(_timings);
    if (inputSession) {
      developer.registerExtension('ext.curl.status', (_, parameters) async {
        final requestedRenderer = parameters['renderer'];
        if (requestedRenderer != null) {
          if (_shader == null ||
              !const ['mesh', 'shader'].contains(requestedRenderer) ||
              _busy ||
              _turning ||
              _gestureActive) {
            return developer.ServiceExtensionResponse.result(
              jsonEncode({'error': 'Renderer switch unavailable'}),
            );
          }
          setState(() => _useShader = requestedRenderer == 'shader');
        }

        if (parameters['finish'] == 'true' && !_captureDone.isCompleted) {
          _captureDone.complete();
        }
        return developer.ServiceExtensionResponse.result(
          jsonEncode({
            'renderer': _activeRenderer,
            'page_start': _pageStart,
            'ready': !_busy && !_turning && !_gestureActive,
            'error': _error,
          }),
        );
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _viewportReady.future;
        if (!mounted) return;
        if (_useShader && _shader == null) await _ensureShader();
        if (!mounted) return;
        if (benchmark) {
          await _benchmark();
        } else {
          _requestedDpr = View.of(context).devicePixelRatio;
          if (Platform.isAndroid || Platform.isIOS) {
            _size = _availableSize;
            _spread = false;
          }
          await _prepare();
          if (inputSession) await _inputSession();
        }
      } catch (error, stack) {
        debugPrint('$error\n$stack');
        if (mounted) {
          setState(() {
            _error = error.toString();
            _busy = false;
          });
        }
        if (benchmark) exit(1);
      }
    });
  }

  void _timings(List<ui.FrameTiming> timings) {
    _frames.addAll(timings);
    if (_frames.length > 2000) _frames.removeRange(0, _frames.length - 2000);
    _input.frames(timings);
    _renderRequests.frames(timings);
  }

  void _markCanvasPaint() {
    final frame = ui.PlatformDispatcher.instance.frameData.frameNumber;
    // 后端调用到 raster 完成；不冒充指针事件或显示呈现延迟。
    _renderRequests.record(
      Duration.zero,
      dispatchMicros: developer.Timeline.now,
    );
    _renderRequests.markPaint(
      frame,
      progress: _animation.value,
      renderer: _activeRenderer,
    );
    _input.markPaint(
      frame,
      progress: _animation.value,
      renderer: _activeRenderer,
    );
  }

  Future<void> _ensureShader() async {
    if (_shader != null) return;
    final program =
        await (widget.loadShader?.call() ??
            ui.FragmentProgram.fromAsset(curlShaderAsset));
    if (mounted) _shader = program.fragmentShader();
  }

  Future<void> _selectRenderer(CurlRendererChoice choice) async {
    if (_busy || benchmark || _turning || _gestureActive) return;
    final backend = resolveCurlBackend(choice, defaultTargetPlatform);
    if ((backend == CurlBackend.shader) == _useShader) {
      setState(() {
        _rendererChoice = choice;
        _rendererError = null;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      // 仅准备目标管线，保留当前页、文件会话和同一组纹理。
      if (backend == CurlBackend.shader) {
        await _ensureShader();
        if (!mounted) return;
        if (shaderWarmup) {
          _shaderWarmupDuration = await (_shaderWarmup ??= warmCurlShader(
            _shader!,
            _textures!.images,
            spread: _spread,
            opaquePages: true,
            paperColor: _paperColor,
          ));
        }
      } else if (Platform.isIOS && meshWarmup) {
        _meshWarmupDuration = await (_meshWarmup ??= warmCurlMesh(
          _textures!.images,
          size: _size,
          pixelRatio: View.of(context).devicePixelRatio,
          spread: _spread,
          opaquePages: true,
          paperColor: _paperColor,
        ));
      }
      if (!mounted) return;
      setState(() {
        _rendererChoice = choice;
        _useShader = backend == CurlBackend.shader;
        _rendererError = null;
      });
    } catch (error) {
      _shaderWarmup = null;
      _meshWarmup = null;
      if (mounted) {
        setState(() => _rendererError = 'Renderer switch failed: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prepare() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    _animation.stop();
    _animation.value = 0;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final oldCache = _cache;
    oldCache?.dispose();
    await oldCache?.settled;
    _textures = null;
    _initialPreparation = {};
    final pageSize = Size(
      _spread ? _size.width / 2 : _size.width,
      _size.height,
    );
    final mobile = Platform.isAndroid || Platform.isIOS;
    final pixels = mobile ? 1000000 : 2000000;
    // 每次都从目标 DPR 计算，避免单页限额永久降低后续双页的清晰度。
    _dpr = math.min(
      _requestedDpr,
      math.sqrt(pixels / (pageSize.width * pageSize.height)),
    );
    final kind = _kind;
    await widget.realSource?.open(kind, pageSize);
    final dpr = _dpr;
    _cache = PageTextureCache(
      bytesPerPage:
          (pageSize.width * dpr).ceil() * (pageSize.height * dpr).ceil() * 4,
      maxBytes: (mobile ? 32 : 64) * 1024 * 1024,
      load: (page) async => widget.realSource?.has(kind) == true
          ? widget.realSource!.load(page, dpr)
          : (await preparePages(
              kind,
              pageSize,
              dpr,
              pageNumbers: [page],
            )).images.single,
    );
    _pageStart = 0;
    await _loadWindow(0);
  }

  Future<void> _loadWindow(int anchor, {double progress = 0}) async {
    final cache = _cache!;
    final next = {for (var i = 0; i < _faceCount; i++) anchor + i};
    final old = _textures == null || _busy
        ? <int>{}
        : {for (var i = 0; i < _textures!.images.length; i++) _pageStart + i};
    cache.pin({...old, ...next});
    final watch = Stopwatch()..start();
    try {
      final images = <ui.Image>[];
      for (final page in next) {
        images.add(await cache.get(page));
      }
      if (!mounted || cache != _cache) return;
      final decodeElapsedMs = watch.elapsedMicroseconds / 1000;
      if (_shader != null && shaderWarmup) {
        try {
          _shaderWarmupDuration = await (_shaderWarmup ??= warmCurlShader(
            _shader!,
            images,
            spread: _spread,
            opaquePages: true,
            paperColor: _paperColor,
          ));
        } catch (_) {
          _shaderWarmup = null;
          rethrow;
        }
        if (!mounted || cache != _cache) return;
      }

      // iOS 网格首次曲面绘制可能在 raster 阶段建管线；先完成真实尺度的离屏绘制。
      if (Platform.isIOS && meshWarmup && _activeRenderer == 'mesh') {
        try {
          _meshWarmupDuration = await (_meshWarmup ??= warmCurlMesh(
            images,
            size: _size,
            pixelRatio: View.of(context).devicePixelRatio,
            spread: _spread,
            opaquePages: true,
            paperColor: _paperColor,
          ));
        } catch (_) {
          _meshWarmup = null;
          rethrow;
        }
        if (!mounted || cache != _cache) return;
      }

      final rssBeforeNative = ProcessInfo.currentRss;
      if (_metal != null) {
        await _metal.prepare(
          images,
          size: _size,
          pixelRatio: View.of(context).devicePixelRatio,
          spread: _spread,
          rtl: _rtl,
          progress: progress,
        );
        if (!mounted || cache != _cache) return;
      }

      final textures = PageTextures(images, watch.elapsedMicroseconds / 1000);
      if (_busy) {
        // 在后台预加载开始前快照首批解码，避免把相邻页混入可见窗口统计。
        _initialPreparation = {
          ...?widget.realSource?.metadata,
          if (_metal != null) ...{
            'native_preparation_ms': _metal.preparationMS,
            'rss_before_native_preparation': rssBeforeNative,
            'rss_after_native_preparation': ProcessInfo.currentRss,
          },
          'visible_face_count': images.length,
          'elapsed_ms': textures.prepareMs,
          'decode_elapsed_ms': decodeElapsedMs,
          'rgba_bytes': textures.rgbaBytes,
          'decode_misses_before_prefetch': cache.misses,
          'resident_bytes_before_prefetch': cache.residentBytes,
        };
      }
      setState(() {
        _textures = textures;
        _pageStart = anchor;
        _animation.value = progress;
        _busy = false;
        _status =
            '${_kind.name} · page ${anchor + 1} · ${_spread ? "double" : "single"} · '
            '${(cache.residentBytes / 1048576).toStringAsFixed(1)} MiB RGBA';
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || cache != _cache) return;
      cache.pin(next);
      unawaited(
        cache.prefetch([
          anchor + _faceCount,
          anchor + _faceCount + 1,
          if (anchor > 0) anchor - 1,
          if (anchor > 1) anchor - 2,
        ]),
      );
    } catch (_) {
      cache.pin(old);
      rethrow;
    }
  }

  Future<void> _turnPage(int delta) async {
    if (_turning || _busy || _gestureActive) return;
    final next = _pageStart + delta * (_spread ? 2 : 1);
    if (next < 0 || next > _lastPage) return;
    _gestureAnchor = _pageStart;
    _gestureDirection = delta;
    _gestureError = null;
    _continuingPose = null;
    _backWindowReady = true;
    // 按钮也进入同一收尾流程，途中仍可抓住纸张拖回。
    _grabY = .5;
    _tilt = 0;
    _cornerWeight = 0;
    _horizontalWeight = 1;
    _diagonalWeight = 0;
    _cornerLimit = 0;
    _controlX = _pageSize.width;
    _startProgress = delta > 0 ? 0 : 1;
    _latestDelta = 0;
    _gestureReady = delta < 0 ? _loadWindow(next, progress: 1) : Future.value();
    if (delta > 0) _animation.value = 0;
    await _finishGesture(0, forcedTarget: delta > 0 ? 1 : 0, updatePose: false);
  }

  Size get _pageSize =>
      Size(_spread ? _size.width / 2 : _size.width, _size.height);

  void _startCurlDrag(DragStartDetails details) {
    if (_busy || (_turning && (!_settling || _useMetal))) return;
    final takeover = _settling;
    _releaseMotion = null;
    _motionTracker.reset();
    _latestPoseStamp = details.sourceTimeStamp;
    _releaseStamp = null;
    _gestureIntentPending = !takeover;
    _gestureIntentSlop = computeHitSlop(
      details.kind ?? ui.PointerDeviceKind.touch,
      MediaQuery.gestureSettingsOf(context),
    );
    if (takeover) {
      _continuingPose = _currentPose;
      // 使旧收尾续体失效，停止 ticker 后由新手势拥有同一张纸。
      _turnToken++;
      _animation.stop();
      _continuingPointer = curlPagePoint(
        _size,
        details.localPosition,
        spread: _spread,
        rtl: _rtl,
      );
    } else {
      _animation.stop();
      _animation.value = 0;
      _continuingPose = null;
      _backWindowReady = true;
      _gestureDirection = 0;
      _gestureAnchor = _pageStart;
      _gestureReady = Future.value();
      _gestureError = null;
      _dragOrigin = curlPagePoint(
        _size,
        _pointerDown,
        spread: _spread,
        rtl: _rtl,
      );
    }
    _dragStart = takeover ? details.localPosition.dx : _pointerDown.dx;
    _latestPoint = takeover ? _continuingPointer : _dragOrigin;
    _latestDelta = 0;
    _startProgress = _animation.value;
    setState(() {
      _turning = false;
      _settling = false;
      _gestureActive = true;
      if (!takeover) {
        _grabY = _dragOrigin.dy / _size.height;
        _tilt = null;
        _cornerWeight = null;
        _horizontalWeight = 0;
        _diagonalWeight = 0;
        _cornerLimit = 0;
      }
    });
    _motionTracker.add(_currentPose, details.sourceTimeStamp);
  }

  void _updateCurlDrag(DragUpdateDetails details) {
    if (!_gestureActive) return;
    _latestPoseStamp = details.sourceTimeStamp;
    _latestDelta = (details.localPosition.dx - _dragStart) * (_rtl ? -1 : 1);
    _latestPoint = curlPagePoint(
      _size,
      details.localPosition,
      spread: _spread,
      rtl: _rtl,
    );
    if (_gestureIntentPending) {
      // 识别器可能在首个移动前启动，等非零二维 update 再判定起手方向。
      final delta = _latestPoint - _dragOrigin;
      // 首个亚像素步进可能恰好等斜，须越过设备的标准抖动范围再锁定方向。
      if (delta.distanceSquared < _gestureIntentSlop * _gestureIntentSlop) {
        return;
      }
      _gestureIntentPending = false;
      if (!curlDragHasHorizontalIntent(delta)) {
        _gestureActive = false;
        return;
      }
    }
    if (_gestureDirection == 0 && _latestDelta.abs() > 1) {
      if (_latestDelta > 0 && _pageStart > 0) {
        _gestureDirection = -1;
        _backWindowReady = false;
        _startProgress = 1;
        _gestureReady = _loadWindow(_pageStart - (_spread ? 2 : 1), progress: 1)
            .then((_) {
              _backWindowReady = true;
              if (_gestureActive) _applyGesturePose();
            })
            .catchError((Object error) {
              _gestureError = error;
            });
      } else if (_latestDelta < 0 && _pageStart < _lastPage) {
        _gestureDirection = 1;
      }
    }
    if (_gestureDirection != 0) _applyGesturePose();
  }

  void _applyGesturePose() {
    // 上一页窗口就绪前保持当前平面，不能用当前页纹理播放上一页的曲面。
    if (_gestureDirection < 0 && !_backWindowReady) return;
    CurlDragPose? pose;
    if (_continuingPose case final start?) {
      pose = continueCurlDrag(
        _pageSize,
        start,
        _latestPoint - _continuingPointer,
      );
    } else if (!_useMetal && _gestureDirection > 0 && _dragOrigin.dx > 0) {
      pose = resolveForwardCurlDrag(_pageSize, _dragOrigin, _latestPoint);
    } else if (!_useMetal &&
        _gestureDirection < 0 &&
        (!_spread || _dragOrigin.dx < 0)) {
      pose = resolveBackwardCurlDrag(
        _pageSize,
        _dragOrigin,
        _latestPoint,
        spread: _spread,
      );
    }
    setState(() {
      if (pose != null) {
        _grabY = pose.grabY;
        _tilt = pose.tilt;
        _cornerWeight = pose.cornerWeight;
        _horizontalWeight = pose.horizontalWeight;
        _diagonalWeight = pose.diagonalWeight;
        _cornerLimit = pose.cornerLimit;
        _controlX = pose.controlX;
        _animation.value = pose.progress;
      } else {
        _animation.value = dragProgress(
          _startProgress,
          _latestDelta,
          _pageSize.width,
        );
      }
    });
    _motionTracker.add(_currentPose, _latestPoseStamp);
  }

  Future<void> _finishGesture(
    double? velocity, {
    double? forcedTarget,
    bool updatePose = true,
  }) async {
    if (forcedTarget == null && _gestureIntentPending) {
      _gestureActive = false;
      _gestureIntentPending = false;
      return;
    }
    final token = ++_turnToken;
    setState(() {
      _gestureActive = false;
      _turning = true;
    });
    try {
      await _gestureReady;
      if (!mounted || token != _turnToken) return;
      if (_gestureError != null) throw _gestureError!;
      // 纹理加载期间松手也使用最后一个二维位置，不退回线性进度。
      if (updatePose && _gestureDirection != 0) _applyGesturePose();
      final target =
          forcedTarget ??
          (velocity == null
              ? (_gestureDirection < 0 ? 1.0 : 0.0)
              : settleTarget(
                  dragProgress(_startProgress, _latestDelta, _pageSize.width),
                  velocity,
                  _size.width,
                ));
      _settling = true;
      _releaseMotion = CurlReleaseMotion(
        start: _currentPose,
        velocity: velocity == null || forcedTarget != null
            ? const CurlPoseVelocity()
            : _motionTracker.velocityAt(_releaseStamp),
        target: target,
        size: _pageSize,
      );
      await _animation.animateWith(_releaseMotion!).orCancel;
      if (!mounted || token != _turnToken) return;
      _settling = false;
      _releaseMotion = null;
      if (_gestureDirection > 0 && target == 1) {
        await _loadWindow(_gestureAnchor + (_spread ? 2 : 1));
      } else if (_gestureDirection < 0 && target == 1) {
        await _loadWindow(_gestureAnchor);
      }
      if (mounted && token == _turnToken) {
        _animation.value = 0;
        _continuingPose = null;
      }
    } on TickerCanceled {
      // 新手势已接管；旧动画不得提交页序或清除新手势的状态。
    } catch (error) {
      if (mounted && token == _turnToken) {
        _animation.value = 0;
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && token == _turnToken) {
        setState(() {
          _settling = false;
          _releaseMotion = null;
          _turning = false;
        });
      }
    }
  }

  Future<void> _inputSession() async {
    if (_useMetal) {
      await _metal!.calibrateClock(reset: true);
      await _metal.metrics(reset: true);
    }
    debugPrint('CURL_INPUT_READY');
    // 以第一条实际输入为采样起点，避免启动/构建等待消耗交互窗口。
    await _inputStarted.future;
    debugPrint('CURL_INPUT_STARTED');
    final memory = <Map<String, Object>>[];
    for (var i = 0; i < 60 && !_captureDone.isCompleted; i++) {
      await Future.any([
        Future<void>.delayed(const Duration(seconds: 1)),
        _captureDone.future,
      ]);
      memory.add({
        'second': i + 1,
        'rss_bytes': ProcessInfo.currentRss,
        ..._cache!.metrics,
      });
    }
    if (!_captureDone.isCompleted) {
      throw StateError('Input driver did not finish capture');
    }
    if (!mounted) return;
    final data = {
      'renderer': _activeRenderer,
      'initial_preparation': _initialPreparation,
      'visible_face_count': _textures!.images.length,
      'mesh_warmup_enabled': Platform.isIOS && meshWarmup,
      'mesh_warmup_ms': (_meshWarmupDuration?.inMicroseconds ?? 0) / 1000,
      'shader_warmup_enabled': shaderWarmup,
      'shader_warmup_ms': (_shaderWarmupDuration?.inMicroseconds ?? 0) / 1000,
      'logical_width': _size.width,
      'logical_height': _size.height,
      'texture_dpr': _dpr,
      'window_dpr': View.of(context).devicePixelRatio,
      'execution_target': simulated ? 'simulator' : 'physical-mobile',
      'timing_statistics_usable': !simulated && kProfileMode,
      'input': _input.metrics,
      if (_metal != null && _useMetal)
        'metal': await _metal.metrics(frames: _frames),
      'memory_samples': memory,
      'frames': summarizeFrames(_frames),
      'page_start': _pageStart,
    };
    final dir = Directory('${Directory.systemTemp.path}/fbooks-page-curl-v2')
      ..createSync(recursive: true);
    await File('${dir.path}/input.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    debugPrint('CURL_INPUT_RESULT ${jsonEncode(data)}');
    debugPrint('CURL_INPUT_COMPLETE ${dir.path}/input.json');
  }

  Future<void> _benchmark() async {
    final dir = Directory(
      output.isEmpty
          ? '${Directory.systemTemp.path}/fbooks-page-curl-v2'
          : output,
    )..createSync(recursive: true);
    final results = <Map<String, Object?>>[];
    final mobile = Platform.isAndroid || Platform.isIOS;
    final nativeDpr = View.of(context).devicePixelRatio;
    const widthArgument = String.fromEnvironment('CURL_BENCH_WIDTH');
    const heightArgument = String.fromEnvironment('CURL_BENCH_HEIGHT');
    final fixedWidth = double.tryParse(widthArgument);
    final fixedHeight = double.tryParse(heightArgument);
    if ((widthArgument.isNotEmpty || heightArgument.isNotEmpty) &&
        (fixedWidth == null ||
            fixedHeight == null ||
            fixedWidth <= 0 ||
            fixedHeight <= 0 ||
            !fixedWidth.isFinite ||
            !fixedHeight.isFinite)) {
      throw ArgumentError(
        'Benchmark width and height must both be positive finite numbers',
      );
    }
    final nativeSize = fixedWidth == null
        ? _availableSize
        : Size(fixedWidth, fixedHeight!);
    final profiles = mobile || fixedWidth != null
        ? [
            (
              name: 'native-${Platform.operatingSystem}',
              size: nativeSize,
              dpr: nativeDpr,
            ),
          ]
        : [
            (name: 'phone', size: const Size(390, 700), dpr: 3.0),
            (name: 'tablet-landscape', size: const Size(1024, 700), dpr: 2.0),
            (name: 'desktop', size: const Size(1200, 700), dpr: 2.0),
          ];
    for (final profile in profiles) {
      for (final kind in PageKind.values) {
        for (final spread in [false, true]) {
          _size = profile.size;
          _requestedDpr = profile.dpr;
          _kind = kind;
          _spread = spread;
          await _prepare();
          final modes = renderer == 'metal-compare'
              ? ((_kind.index + (_spread ? 1 : 0)).isEven
                    ? ['mesh', 'metal']
                    : ['metal', 'mesh'])
              : renderer == 'compare'
              ? ((_kind.index + (_spread ? 1 : 0)).isEven
                    ? ['mesh', 'shader']
                    : ['shader', 'mesh'])
              : [
                  renderer == 'auto'
                      ? resolveCurlBackend(
                          _rendererChoice,
                          defaultTargetPlatform,
                        ).name
                      : renderer,
                ];
          for (final mode in modes) {
            setState(() {
              _useShader = mode == 'shader';
              _useMetal = mode == 'metal';
            });
            final id =
                '${profile.name}-${kind.name}-${spread ? "double" : "single"}${renderer.endsWith("compare") ? "-$mode" : ""}';
            // 热身与采样均包含动态网格、光影及纹理绘制；不含页面准备。
            await _animation.forward(from: 0);
            await _animation.reverse();
            await Future<void>.delayed(const Duration(milliseconds: 1100));
            if (_useMetal) {
              await _metal!.calibrateClock(reset: true);
              await _metal.metrics(reset: true);
            }
            _frames.clear();
            _renderRequests = InputLatencyProbe();
            void firstFrame(Duration _) {
              _firstVsync ??= SchedulerBinding
                  .instance
                  .currentSystemFrameTimeStamp
                  .inMicroseconds;
            }

            _firstVsync = null;
            SchedulerBinding.instance.addPostFrameCallback(firstFrame);
            final elapsed = Stopwatch()..start();
            for (var i = 0; i < 2; i++) {
              await _animation.forward(from: 0);
              await _animation.reverse();
            }
            elapsed.stop();
            _lastVsync = SchedulerBinding
                .instance
                .currentSystemFrameTimeStamp
                .inMicroseconds;
            // FrameTiming 在 profile 模式可能批量晚到，按实际 vsync 时间过滤。
            await Future<void>.delayed(const Duration(milliseconds: 1100));
            final frames = _frames.where((f) {
              final vsync = f.timestampInMicroseconds(ui.FramePhase.vsyncStart);
              return _firstVsync != null &&
                  vsync >= _firstVsync! &&
                  vsync <= _lastVsync!;
            }).toList();
            if (frames.isEmpty || (!simulated && frames.length < 30)) {
              throw StateError(
                'Insufficient FrameTiming samples: ${frames.length}',
              );
            }
            final nativeMetrics = _useMetal
                ? await _metal!.metrics(frames: frames)
                : null;
            if (!mounted) return;
            final render =
                _boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final result = <String, Object?>{
              'id': id,
              'renderer': _activeRenderer,
              if (_useMetal) 'metal': nativeMetrics,
              'renderer_request_to_flutter_raster_finish_ms': _useMetal
                  ? nativeMetrics!['request_to_flutter_raster_finish_ms']
                  : _renderRequests.metrics['dispatch_to_raster_finish_ms'],
              'mesh_warmup_enabled': Platform.isIOS && meshWarmup,
              'mesh_warmup_ms':
                  (_meshWarmupDuration?.inMicroseconds ?? 0) / 1000,
              'shader_warmup_enabled': shaderWarmup,
              'shader_warmup_ms':
                  (_shaderWarmupDuration?.inMicroseconds ?? 0) / 1000,
              'mesh_columns': _useShader ? null : 96,
              'mesh_rows': _useShader ? null : 24,
              'timing_scope': _useMetal
                  ? 'Flutter-only; native GPU and texture bridge are recorded separately in metal'
                  : 'Flutter Canvas pipeline',
              'timing_statistics_usable':
                  frames.length >= 30 && !simulated && kProfileMode,
              'source': kind.name,
              'spread': spread,
              'logical_width': _size.width,
              'logical_height': _size.height,
              'texture_dpr': _dpr,
              'window_dpr': View.of(context).devicePixelRatio,
              'effective_logical_scale': render
                  .getTransformTo(null)
                  .getMaxScaleOnAxis(),
              'actual_paint_width': render.size.width,
              'actual_paint_height': render.size.height,
              'initial_preparation': _initialPreparation,
              'visible_face_count': _textures!.images.length,
              'prepare_visible_pages_ms': _textures!.prepareMs,
              'resident_visible_page_rgba_bytes': _textures!.rgbaBytes,
              'process_rss_bytes': ProcessInfo.currentRss,
              'texture_width': _textures!.images.first.width,
              'texture_height': _textures!.images.first.height,
              'texture_cache': _cache!.metrics,
              'measured_animation_ms': elapsed.elapsedMilliseconds,
              ...summarizeFrames(frames),
            };
            results.add(result);
            debugPrint('CURL_RESULT ${jsonEncode(result)}');
            if (capture && (profile.name == 'desktop' || mobile)) {
              _animation.value = 0.52;
              await WidgetsBinding.instance.endOfFrame;
              final image = await render.toImage(pixelRatio: 1);
              try {
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File('${dir.path}/$id.png')
                    .writeAsBytes(data!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            }
            if (mobile) {
              final memory = <Map<String, Object>>[];
              for (final anchor in [1, 2, 4, 6, 8, 6, 4, 2, 0]) {
                if (anchor > _lastPage) continue;
                await _loadWindow(anchor);
                memory.add({
                  'anchor': anchor,
                  'rss_bytes': ProcessInfo.currentRss,
                  ..._cache!.metrics,
                });
              }
              result['cache_stress'] = memory;
            }
            await File('${dir.path}/results.json').writeAsString(
              const JsonEncoder.withIndent('  ').convert({
                'run_id': const String.fromEnvironment('CURL_RUN_ID'),
                'mode': kProfileMode
                    ? 'profile'
                    : (kReleaseMode ? 'release' : 'debug'),
                'os': Platform.operatingSystemVersion,
                'dart': Platform.version,
                'renderer': renderer,
                'mesh_columns': renderer == 'mesh' ? 96 : null,
                'mesh_rows': renderer == 'mesh' ? 24 : null,
                'measurement': 'warm page textures; two forward/reverse cycles; vsync-filtered FrameTiming',
                'geometry': renderer == 'auto'
                    ? 'Per-result platform-selected mesh or analytic inverse row curl'
                    : renderer.startsWith('metal')
                    ? 'Per-result CPU mesh or Metal vertex deformation with depth testing'
                    : renderer == 'compare'
                    ? 'Per-result renderer: mesh row curl or analytic inverse row curl'
                    : renderer == 'mesh'
                    ? 'spine-anchored row curl with corner control'
                    : 'analytic inverse row curl; three vertical corrections; analytic shadow',
                'execution_target': simulated
                    ? 'simulator'
                    : mobile
                    ? 'physical-mobile'
                    : 'desktop',
                'physical_mobile': mobile && !simulated,
                'limitations': [
                  'Per-result initial_preparation identifies real input or synthetic fixture.',
                  'Real EPUB uses one selected chapter and production pagination; selection and persisted progress are not integrated.',
                  if (!mobile && fixedWidth == null)
                    'Phone/tablet dimensions run on desktop GPU.',
                  if (simulated) 'Simulator timings and process memory do not predict physical device performance.',
                  'RGBA bytes exclude PDF/native/transient/cached GPU allocations; RSS is whole-process memory.',
                  'Pipeline budget exceedance is not measured dropped-frame rate or input-to-display latency.',
                  'No Apple Books side-by-side comparison; row curl is not a physical paper solver.',
                  if (renderer.startsWith('metal')) 'Metal uses GPU vertex deformation and hardware depth; shadows differ from the Canvas mesh. External texture acquisition is measured separately from Flutter frame timings.',
                  if (renderer == 'shader' || renderer == 'compare') 'Shader uses an approximate vertical inverse, height-dependent analytic shadows and pixel coverage edges. It is not pixel-equivalent to the mesh.',
                ],
                'results': results,
              }),
            );
          }
        }
      }
    }
    debugPrint('CURL_COMPLETE ${dir.path}/results.json');
    exit(0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_timings);
    _animation.dispose();
    _shader?.dispose();
    _cache?.dispose();
    unawaited(
      (_cache?.settled ?? Future<void>.value()).then(
        (_) => widget.realSource?.closeSession(),
      ),
    );
    if (_metal != null) unawaited(_metal.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff23272b),
      appBar: AppBar(title: const Text('Paper curl lab · isolated prototype')),
      body: SafeArea(
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<PageKind>(
                  value: _kind,
                  items: [
                    for (final kind in PageKind.values)
                      DropdownMenuItem(value: kind, child: Text(kind.name)),
                  ],
                  onChanged: _busy || benchmark
                      ? null
                      : (value) async {
                          if (_turning || _gestureActive) return;
                          _kind = value!;
                          await _prepare();
                        },
                ),
                TextButton(
                  onPressed: _busy || benchmark
                      ? null
                      : () async {
                          if (_turning || _gestureActive) return;
                          _spread = !_spread;
                          await _prepare();
                        },
                  child: Text(_spread ? 'Double page' : 'Single page'),
                ),
                TextButton(
                  onPressed: _busy || benchmark
                      ? null
                      : () {
                          if (!_turning && !_gestureActive) {
                            setState(() => _rtl = !_rtl);
                          }
                        },
                  child: Text(_rtl ? 'RTL' : 'LTR'),
                ),
                if (renderer == 'auto')
                  DropdownButton<CurlRendererChoice>(
                    key: const Key('curl-renderer-choice'),
                    value: _rendererChoice,
                    items: [
                      DropdownMenuItem(
                        value: CurlRendererChoice.automatic,
                        child: Text(
                          'Auto (${defaultCurlBackend(defaultTargetPlatform).name})',
                        ),
                      ),
                      const DropdownMenuItem(
                        value: CurlRendererChoice.mesh,
                        child: Text('Mesh'),
                      ),
                      const DropdownMenuItem(
                        value: CurlRendererChoice.shader,
                        child: Text('Shader'),
                      ),
                    ],
                    onChanged: _busy || benchmark || _turning || _gestureActive
                        ? null
                        : (choice) => unawaited(_selectRenderer(choice!)),
                  ),
                if (renderer.endsWith('compare'))
                  TextButton(
                    onPressed: _busy || benchmark
                        ? null
                        : () {
                            if (_turning || _gestureActive) return;
                            setState(() {
                              if (_metal != null) {
                                _useMetal = !_useMetal;
                              } else {
                                _useShader = !_useShader;
                              }
                            });
                          },
                    child: Text('Renderer: $_activeRenderer'),
                  ),
                if (inputSession)
                  TextButton(
                    onPressed: _captureDone.isCompleted
                        ? null
                        : () => setState(() => _captureDone.complete()),
                    child: const Text('Finish capture'),
                  ),
                TextButton(
                  onPressed: _busy || benchmark ? null : () => _turnPage(-1),
                  child: const Text('Previous'),
                ),
                TextButton(
                  onPressed: _busy || benchmark ? null : () => _turnPage(1),
                  child: const Text('Next'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                height: 44,
                child: Text(
                  _error ??
                      (_rendererError == null
                          ? _status
                          : '$_status\n$_rendererError'),
                  maxLines: 2,
                  style: TextStyle(
                    color: _error == null && _rendererError == null
                        ? Colors.white70
                        : Colors.redAccent,
                  ),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  _availableSize = constraints.biggest;
                  if (!_viewportReady.isCompleted &&
                      constraints.maxWidth > 100 &&
                      constraints.maxHeight > 100) {
                    _viewportReady.complete(constraints.biggest);
                  }
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RepaintBoundary(
                        key: _boundary,
                        child: SizedBox(
                          width: _size.width,
                          height: _size.height,
                          child: _busy || _textures == null
                              ? const Center(child: CircularProgressIndicator())
                              : Listener(
                                  onPointerMove: (event) {
                                    if (!benchmark && !_busy) {
                                      _input.record(event.timeStamp);
                                      if (_useMetal) _metal?.recordInput();
                                      if (!_inputStarted.isCompleted) {
                                        _inputStarted.complete();
                                      }
                                    }
                                  },
                                  onPointerUp: (event) =>
                                      _releaseStamp = event.timeStamp,
                                  onPointerCancel: (_) {
                                    // 已接受的拖动被系统取消时，框架仍可能回调 onEnd。
                                    // 先清除活动手势并回弹，避免按普通松手阈值完成翻页。
                                    if (_gestureActive) {
                                      unawaited(_finishGesture(null));
                                    }
                                  },
                                  child: GestureDetector(
                                    key: const Key('curl-surface'),
                                    onHorizontalDragDown: benchmark
                                        ? null
                                        : (d) => _pointerDown = d.localPosition,
                                    onHorizontalDragStart: benchmark
                                        ? null
                                        : _startCurlDrag,
                                    onHorizontalDragUpdate: benchmark
                                        ? null
                                        : _updateCurlDrag,
                                    onHorizontalDragEnd: benchmark
                                        ? null
                                        : (d) {
                                            if (_gestureActive) {
                                              unawaited(
                                                _finishGesture(
                                                  (d.primaryVelocity ?? 0) *
                                                      (_rtl ? -1 : 1),
                                                ),
                                              );
                                            }
                                          },
                                    onHorizontalDragCancel: benchmark
                                        ? null
                                        : () {
                                            if (_gestureActive) {
                                              unawaited(_finishGesture(null));
                                            }
                                          },
                                    child: AnimatedBuilder(
                                      animation: _animation,
                                      builder: (_, _) => _useMetal
                                          ? MetalCurlSurface(
                                              controller: _metal!,
                                              progress: _animation.value,
                                              grabY: _grabY,
                                              spread: _spread,
                                              rtl: _rtl,
                                              size: _size,
                                            )
                                          : CustomPaint(
                                              painter: !_useShader
                                                  ? CurlPainter(
                                                      mesh: _mesh,
                                                      opaquePages: true,
                                                      images: _textures!.images,
                                                      progress:
                                                          _animation.value,
                                                      spread: _spread,
                                                      grabY: _grabY,
                                                      tilt: _tilt,
                                                      cornerWeight:
                                                          _cornerWeight,
                                                      horizontalWeight:
                                                          _horizontalWeight,
                                                      diagonalWeight:
                                                          _diagonalWeight,
                                                      cornerLimit: _cornerLimit,
                                                      rtl: _rtl,
                                                      paperColor: _paperColor,
                                                      onPaint: _markCanvasPaint,
                                                    )
                                                  : CurlShaderPainter(
                                                      mesh: _mesh,
                                                      opaquePages: true,
                                                      shader: _shader!,
                                                      pixelRatio:
                                                          View.of(
                                                            context,
                                                          ).devicePixelRatio *
                                                          math.min(
                                                            1,
                                                            math.min(
                                                              constraints
                                                                      .maxWidth /
                                                                  _size.width,
                                                              constraints
                                                                      .maxHeight /
                                                                  _size.height,
                                                            ),
                                                          ),
                                                      images: _textures!.images,
                                                      progress:
                                                          _animation.value,
                                                      spread: _spread,
                                                      grabY: _grabY,
                                                      tilt: _tilt,
                                                      cornerWeight:
                                                          _cornerWeight,
                                                      horizontalWeight:
                                                          _horizontalWeight,
                                                      diagonalWeight:
                                                          _diagonalWeight,
                                                      cornerLimit: _cornerLimit,
                                                      rtl: _rtl,
                                                      paperColor: _paperColor,
                                                      onPaint: _markCanvasPaint,
                                                    ),
                                              size: _size,
                                            ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (!benchmark)
              AnimatedBuilder(
                animation: _animation,
                builder: (_, _) => Slider(
                  // 禁用状态变化时重建，避免 SDK 复用滑块时留下已分离的语义父节点。
                  key: ValueKey(_busy || _turning || _gestureActive),
                  value: _animation.value,
                  onChanged: _busy || _turning || _gestureActive
                      ? null
                      : (v) {
                          if (!_turning && !_gestureActive) {
                            _animation.value = v;
                          }
                        },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
