import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'curl_geometry.dart';
import 'curl_drag.dart';
import 'curl_motion.dart';
import 'curl_painter.dart';
import 'curl_shader_painter.dart';

const _opaqueReference = bool.fromEnvironment('CURL_OPAQUE_REFERENCE');
const _motionCapture = bool.fromEnvironment('CURL_MOTION_CAPTURE');
const _pointerSampling = bool.fromEnvironment('CURL_POINTER_CAPTURE');
const _centerSampling = bool.fromEnvironment('CURL_CENTER_CAPTURE');
const _diagonalSampling = bool.fromEnvironment('CURL_DIAGONAL_CAPTURE');
const _outwardSampling = bool.fromEnvironment('CURL_OUTWARD_CAPTURE');
const _backwardSampling = bool.fromEnvironment('CURL_BACKWARD_CAPTURE');
const _limitSampling = bool.fromEnvironment('CURL_LIMIT_CAPTURE');

// 独立宿主读取调用者复制到 Documents 的三张相邻页截图，不访问正式书库。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  final directory = await getApplicationDocumentsDirectory();
  final images = <ui.Image>[];
  try {
    for (var page = 0; page < 3; page++) {
      final codec = await ui.instantiateImageCodec(
        await File('${directory.path}/reference-$page.png').readAsBytes(),
      );
      try {
        images.add((await codec.getNextFrame()).image);
      } finally {
        codec.dispose();
      }
    }
    final program = await ui.FragmentProgram.fromAsset(curlShaderAsset);
    final output = Directory(
      '${directory.path}/curl-reference-${_limitSampling
          ? 'limit-'
          : _backwardSampling
          ? 'backward-'
          : _outwardSampling
          ? 'outward-'
          : _diagonalSampling
          ? 'diagonal-'
          : _centerSampling
          ? 'center-'
          : ''}${_pointerSampling ? 'pointer' : 'results'}',
    );
    await output.create(recursive: true);
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: CurlReferenceCapture(
          images: images,
          program: program,
          output: output,
          sampleOnStart: const bool.fromEnvironment(
            'CURL_SAMPLE_ON_START',
            defaultValue: true,
          ),
        ),
      ),
    );
  } catch (_) {
    for (final image in images) {
      image.dispose();
    }
    rethrow;
  }
}

class CurlReferenceCapture extends StatefulWidget {
  const CurlReferenceCapture({
    super.key,
    required this.images,
    required this.program,
    required this.output,
    this.sampleOnStart = true,
  });
  final List<ui.Image> images;
  final ui.FragmentProgram program;
  final Directory output;
  final bool sampleOnStart;

  @override
  State<CurlReferenceCapture> createState() => _CurlReferenceCaptureState();
}

class _CurlReferenceCaptureState extends State<CurlReferenceCapture>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final _shader = widget.program.fragmentShader();
  final _mesh = CurlMesh();
  final _boundary = GlobalKey();
  final _timings = <ui.FrameTiming>[];
  final _motionFrames = <ui.FrameTiming>[];
  final _motionReports = <Map<String, Object>>[];
  int _motionStartedMicros = 0;
  bool _measuring = false;
  bool _sampling = true;
  bool _useShader = false;
  Color _paperColor = Colors.white;
  int _page = 0;
  int _turnAnchor = 0;
  int _direction = 0;
  int _turnToken = 0;
  bool _gestureActive = false;
  bool _settling = false;
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

  double _grabY = (_centerSampling || _diagonalSampling || _backwardSampling)
      ? 0.5
      : 732 / 844;
  double _startX = 0;
  double _startProgress = 0;
  Offset _dragOrigin = Offset.zero;
  double _latestDelta = 0;
  double? _tilt;
  double? _cornerWeight;
  double _horizontalWeight = 0;
  double _diagonalWeight = 0;
  double _cornerLimit = 0;
  bool _gestureIntentPending = false;
  double _gestureIntentSlop = 0;
  bool _linearPointerSampling = false;
  final _pointerEvents = <Map<String, Object>>[];
  int _pointerSequence = 0;
  Timer? _idleTimer;
  bool _idleBlack = false;
  final _activePointers = <int>{};

  void _armIdleBlack() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted) return;
      if (_sampling || _animation.isAnimating || _activePointers.isNotEmpty) {
        _armIdleBlack();
        return;
      }
      setState(() => _idleBlack = true);
    });
  }

  void _recordPointer(PointerEvent event, String kind) {
    if (kind == 'down') {
      _activePointers.add(event.pointer);
      if (_idleBlack) setState(() => _idleBlack = false);
      _armIdleBlack();
    } else if (kind == 'up' || kind == 'cancel') {
      _activePointers.remove(event.pointer);
      _armIdleBlack();
    }
    if (_sampling) return;
    if (kind == 'down') _pointerEvents.clear();
    if (_pointerEvents.length < 5000) {
      _pointerEvents.add({
        'kind': kind,
        'time_us': event.timeStamp.inMicroseconds,
        'x': event.localPosition.dx,
        'y': event.localPosition.dy,
      });
    }
    if (kind == 'up' || kind == 'cancel') {
      final sequence = _pointerSequence++;
      final data = jsonEncode({'events': _pointerEvents});
      unawaited(
        File('${widget.output.path}/pointer-$sequence.json')
            .writeAsString(data),
      );
    }
  }

  Offset _sampleOrigin(Size size) => Offset(
    size.width * (_backwardSampling ? 17 : 373) / 390,
    size.height *
        ((_centerSampling || _diagonalSampling || _backwardSampling)
            ? 0.5
            : 732 / 844),
  );

  Offset _samplePointer(Size size, double fraction) => Offset(
    // 停顿点按 WDA 的整数指针坐标量化。
    size.width *
        (_backwardSampling
                ? 17 + 325 * fraction
                : 373 - (_limitSampling ? 160 : 325) * fraction)
            .round() /
        390,
    size.height *
        (_limitSampling
            ? (732 - 632 * fraction).round() / 844
            : _backwardSampling
            ? (422 - 120 * fraction).round() / 844
            : _outwardSampling
            ? (732 + 87 * fraction).round() / 844
            : _diagonalSampling
            ? (422 - 120 * fraction).round() / 844
            : _centerSampling
            ? 0.5
            : (732 - 87 * fraction).round() / 844),
  );

  CurlDragPose _samplePose(Size size, double fraction) =>
      (_backwardSampling ? resolveBackwardCurlDrag : resolveForwardCurlDrag)(
        size,
        _sampleOrigin(size),
        _samplePointer(size, fraction),
      );

  @override
  void initState() {
    super.initState();
    _animation.addListener(_onReleaseTick);
    WidgetsBinding.instance.addTimingsCallback(_onTimings);
    _sampling = widget.sampleOnStart;
    _armIdleBlack();
    if (_sampling) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_sample()));
    }
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    if (_measuring) _timings.addAll(timings);
    if (_motionCapture) {
      _motionFrames.addAll(timings);
      if (_motionFrames.length > 600) _motionFrames.removeRange(0, 300);
    }
  }

  void _startDrag(DragStartDetails details, Size size) {
    if (_motionCapture) _motionStartedMicros = developer.Timeline.now;
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
      _continuingPointer = details.localPosition;
      _turnToken++;
    } else {
      _continuingPose = null;
      _turnAnchor = _page;
      _direction = 0;
    }
    _animation.stop();
    _startX = takeover ? details.localPosition.dx : _dragOrigin.dx;
    _latestPoint = takeover ? _continuingPointer : _dragOrigin;
    _latestDelta = 0;
    _startProgress = takeover ? _animation.value : 0;
    setState(() {
      _settling = false;
      _gestureActive = true;
      if (!takeover) {
        _animation.value = 0;
        _grabY = _dragOrigin.dy / size.height;
        _tilt = null;
        _cornerWeight = null;
        _horizontalWeight = 0;
        _diagonalWeight = 0;
        _cornerLimit = 0;
      }
    });
    _motionTracker.add(_currentPose, details.sourceTimeStamp);
  }

  void _updateDrag(DragUpdateDetails details, Size size) {
    if (!_gestureActive) return;
    _latestPoseStamp = details.sourceTimeStamp;
    _latestPoint = details.localPosition;
    _latestDelta = _latestPoint.dx - _startX;
    if (_gestureIntentPending) {
      // start 可能早于实际移动，在首个非零二维更新中判定。
      final delta = _latestPoint - _dragOrigin;
      if (delta.distanceSquared < _gestureIntentSlop * _gestureIntentSlop) {
        return;
      }
      _gestureIntentPending = false;
      if (!curlDragHasHorizontalIntent(delta)) {
        _gestureActive = false;
        return;
      }
    }
    if (_direction == 0 && _latestDelta.abs() > 1) {
      if (_latestDelta > 0 && _turnAnchor > 0) {
        _direction = -1;
        _startProgress = 1;
        _page = _turnAnchor - 1;
      } else if (_latestDelta < 0 && _turnAnchor < widget.images.length - 1) {
        _direction = 1;
      }
    }
    if (_direction == 0) return;
    final pose = _continuingPose != null
        ? continueCurlDrag(
            size,
            _continuingPose!,
            _latestPoint - _continuingPointer,
          )
        : _direction > 0
        ? resolveForwardCurlDrag(size, _dragOrigin, _latestPoint)
        : resolveBackwardCurlDrag(size, _dragOrigin, _latestPoint);
    setState(() {
      _grabY = pose.grabY;
      _tilt = pose.tilt;
      _cornerWeight = pose.cornerWeight;
      _horizontalWeight = pose.horizontalWeight;
      _diagonalWeight = pose.diagonalWeight;
      _cornerLimit = pose.cornerLimit;
      _controlX = pose.controlX;
      _animation.value = pose.progress;
    });
    _motionTracker.add(_currentPose, _latestPoseStamp);
  }

  Future<void> _finishDrag(double? velocity, Size size) async {
    if (!_gestureActive) return;
    if (_gestureIntentPending) {
      _gestureActive = false;
      _gestureIntentPending = false;
      return;
    }
    final token = ++_turnToken;
    _gestureActive = false;
    final direction = _direction;
    final target = velocity == null
        ? (direction < 0 ? 1.0 : 0.0)
        : settleTarget(
            dragProgress(_startProgress, _latestDelta, size.width),
            velocity,
            size.width,
          );
    _settling = true;
    final dragStarted = _motionStartedMicros;
    final released = developer.Timeline.now;
    var completed = false;
    try {
      _releaseMotion = CurlReleaseMotion(
        start: _currentPose,
        velocity: velocity == null
            ? const CurlPoseVelocity()
            : _motionTracker.velocityAt(_releaseStamp),
        target: target,
        size: size,
      );
      await _animation.animateWith(_releaseMotion!).orCancel;
      if (!mounted || token != _turnToken) return;
      completed = true;
      _settling = false;
      _releaseMotion = null;
      setState(() {
        _page = direction > 0 && target == 1
            ? _turnAnchor + 1
            : direction < 0 && target == 0
            ? _turnAnchor - 1
            : _turnAnchor;
        _animation.value = 0;
        _continuingPose = null;
        _direction = 0;
      });
    } on TickerCanceled {
      // 新手势拥有当前纸张；旧动画不再推进页序。
    } finally {
      if (_motionCapture) {
        final ended = developer.Timeline.now;
        Timer(const Duration(milliseconds: 150), () {
          Iterable<ui.FrameTiming> phase(int from, int to) =>
              _motionFrames.where((f) {
                final stamp = f.timestampInMicroseconds(
                  ui.FramePhase.vsyncStart,
                );
                return stamp >= from && stamp <= to;
              });
          _motionReports.add({
            'target': target,
            'completed': completed,
            'release_duration_ms': (ended - released) / 1000,
            'drag': summarizeFrames(phase(dragStarted, released).toList()),
            'release': summarizeFrames(phase(released, ended).toList()),
          });
          unawaited(
            File('${widget.output.path}/motion-performance.json')
                .writeAsString(jsonEncode({'cases': _motionReports})),
          );
        });
      }
      if (mounted && token == _turnToken) {
        _settling = false;
        _releaseMotion = null;
      }
    }
  }

  Future<void> _sample() async {
    final size = MediaQuery.sizeOf(context);
    final ratio = View.of(context).devicePixelRatio;
    final output = widget.output;
    await output.create(recursive: true);
    final report = <String, Object>{
      'status': 'running',
      'capture_started_utc': DateTime.now().toUtc().toIso8601String(),
      'logical_width': size.width,
      'logical_height': size.height,
      'pixel_ratio': ratio,
      'opaque_reference': _opaqueReference,
      'source': const String.fromEnvironment(
        'CURL_REFERENCE_SOURCE',
        defaultValue: 'books-screenshot-textures',
      ),
      'pose_input': _pointerSampling ? 'pointer-trace' : 'scalar-progress',
      'sample_mode': _limitSampling
          ? 'limit'
          : _backwardSampling
          ? 'backward'
          : _outwardSampling
          ? 'outward'
          : _diagonalSampling
          ? 'diagonal'
          : _centerSampling
          ? 'center'
          : 'corner',
      if (_backwardSampling)
        'control_policy':
            'calibrated-free-edge; 4/390 page-width offset after entry ramp',
      'shader_developable_fallback': 'Mesh for local, tilted or limit surfaces; analytic shader for horizontal cylinder',
      if (_pointerSampling)
        'pointer_origin': [_sampleOrigin(size).dx, _sampleOrigin(size).dy],
      if (_pointerSampling)
        'pointer_samples': [
          for (final fraction in [0.25, 0.5, 0.75])
            (() {
              final pose = _samplePose(size, fraction);
              final anchor = _sampleOrigin(size);
              final projected = CurlGeometry(
                size: size,
                progress: pose.progress,
                grabY: pose.grabY,
                tilt: pose.tilt,
                cornerWeight: pose.cornerWeight,
                horizontalWeight: pose.horizontalWeight,
                diagonalWeight: pose.diagonalWeight,
                cornerLimit: pose.cornerLimit,
              ).project(anchor.dx, anchor.dy);
              return {
                'fraction': fraction,
                'progress': pose.progress,
                'linear_progress': dragProgress(
                  _backwardSampling ? 1 : 0,
                  _samplePointer(size, fraction).dx - anchor.dx,
                  size.width,
                ),
                'tilt': pose.tilt,
                'corner_weight': pose.cornerWeight,
                'horizontal_weight': pose.horizontalWeight,
                'diagonal_weight': pose.diagonalWeight,
                'corner_limit': pose.cornerLimit,
                'crease_gain': curlCreaseGainForProgress(
                  pose.progress,
                  hasDirection: true,
                  cornerWeight: pose.cornerWeight,
                ),
                'control_x': pose.controlX,
                'control_error_pixels':
                    (CurlGeometry(
                              size: size,
                              progress: pose.progress,
                              grabY: pose.grabY,
                              tilt: pose.tilt,
                              cornerWeight: pose.cornerWeight,
                              horizontalWeight: pose.horizontalWeight,
                              diagonalWeight: pose.diagonalWeight,
                              cornerLimit: pose.cornerLimit,
                            ).project(pose.controlX, anchor.dy).position -
                            _samplePointer(size, fraction))
                        .distance,
                'anchor_error_pixels':
                    (projected.position - _samplePointer(size, fraction))
                        .distance,
              };
            })(),
        ],
    };
    // 先覆盖旧报告，避免安装后旧进程仍运行或采样中断时误用上轮结果。
    await File('${output.path}/result.json').writeAsString(jsonEncode(report));
    try {
      for (final image in widget.images) {
        if (image.width != (size.width * ratio).round() ||
            image.height != (size.height * ratio).round()) {
          throw StateError('Reference textures must match the device viewport');
        }
      }
      final performance = <Map<String, Object>>[];
      for (var round = 0; round < 3; round++) {
        for (final shader in [false, true]) {
          for (final legacy in round.isEven ? [true, false] : [false, true]) {
            setState(() {
              _useShader = shader;
              _paperColor = legacy ? const Color(0xfffaf6ec) : Colors.white;
            });
            final name =
                '${shader ? 'shader' : 'mesh'}-${legacy ? 'legacy' : 'neutral'}';
            if (round == 0) {
              for (final progress
                  in _pointerSampling ? [0.25, 0.5, 0.75] : [0.15, 0.45, 0.7]) {
                for (final linear
                    in _pointerSampling ? [true, false] : [false]) {
                  setState(() => _linearPointerSampling = linear);
                  _animation.value = progress;
                  await WidgetsBinding.instance.endOfFrame;
                  final boundary =
                      _boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary;
                  final image = await boundary.toImage(pixelRatio: ratio);
                  try {
                    final bytes = await image.toByteData(
                      format: ui.ImageByteFormat.png,
                    );
                    await File(
                      '${output.path}/${linear ? 'linear-' : ''}$name-$progress.png',
                    ).writeAsBytes(bytes!.buffer.asUint8List());
                  } finally {
                    image.dispose();
                  }
                }
              }
            }
            // 先提交本材质的真实绘制，并等待截图/编码帧退出流水线。
            _animation.value = 0.52;
            await WidgetsBinding.instance.endOfFrame;
            // 离屏截图和编码结束后再采暖态动画，不把 PNG 工作计入帧耗时。
            await Future<void>.delayed(const Duration(milliseconds: 200));
            _animation.duration = const Duration(seconds: 2);
            _timings.clear();
            _measuring = true;
            await _animation.forward(from: 0).orCancel;
            await Future<void>.delayed(const Duration(milliseconds: 100));
            _measuring = false;
            performance.add({
              'case': name,
              'round': round,
              ...summarizeFrames(_timings),
            });
          }
        }
      }
      report['performance'] = performance;
      report['status'] = 'passed';
    } catch (error) {
      report['status'] = 'failed';
      report['error'] = error.runtimeType.toString();
    } finally {
      _measuring = false;
      await File('${output.path}/result.json')
          .writeAsString(jsonEncode(report));
      if (mounted) {
        setState(() {
          _sampling = false;
          _useShader = false;
          _paperColor = Colors.white;
          _animation.duration = const Duration(milliseconds: 650);
          _animation.value = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          onPointerDown: (event) => _recordPointer(event, 'down'),
          onPointerMove: (event) => _recordPointer(event, 'move'),
          onPointerUp: (event) {
            _releaseStamp = event.timeStamp;
            _recordPointer(event, 'up');
          },
          onPointerCancel: (event) {
            _recordPointer(event, 'cancel');
            // 系统取消后框架仍可能回调 onEnd；先交还原页，不能按距离提交。
            if (_gestureActive) unawaited(_finishDrag(null, size));
          },
          // 只遮盖独立测试 App 的显示，不锁设备；原始触摸仍送达采样与手势。
          // 覆盖层位于采集边界之外，自动采样及持指停驻时不启用。
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(color: _idleBlack ? Colors.black : null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragDown: _sampling
                  ? null
                  : (details) => _dragOrigin = details.localPosition,
              onHorizontalDragStart: _sampling
                  ? null
                  : (details) => _startDrag(details, size),
              onHorizontalDragUpdate: _sampling
                  ? null
                  : (details) => _updateDrag(details, size),
              onHorizontalDragEnd: _sampling
                  ? null
                  : (details) {
                      unawaited(
                        _finishDrag(details.primaryVelocity ?? 0, size),
                      );
                    },
              onHorizontalDragCancel: _sampling
                  ? null
                  : () {
                      unawaited(_finishDrag(null, size));
                    },
              child: RepaintBoundary(
                key: _boundary,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (_, _) {
                    final images = [
                      widget.images[_page],
                      widget.images[(_page + 1).clamp(
                        0,
                        widget.images.length - 1,
                      )],
                    ];
                    final pointerPose = _sampling && _pointerSampling
                        ? _samplePose(size, _animation.value)
                        : null;
                    final pose = _linearPointerSampling ? null : pointerPose;
                    final progress =
                        pose?.progress ??
                        (_sampling && _pointerSampling
                            ? dragProgress(
                                _backwardSampling ? 1 : 0,
                                _samplePointer(size, _animation.value).dx -
                                    _sampleOrigin(size).dx,
                                size.width,
                              )
                            : _animation.value);
                    return CustomPaint(
                      size: size,
                      painter: _useShader
                          ? CurlShaderPainter(
                              mesh: _mesh,
                              opaquePages: _opaqueReference,
                              shader: _shader,
                              images: images,
                              progress: progress,
                              grabY: pose?.grabY ?? _grabY,
                              tilt: pose?.tilt ?? _tilt,
                              cornerWeight: pose?.cornerWeight ?? _cornerWeight,
                              horizontalWeight:
                                  pointerPose?.horizontalWeight ??
                                  _horizontalWeight,
                              diagonalWeight:
                                  pointerPose?.diagonalWeight ??
                                  _diagonalWeight,
                              cornerLimit: pose?.cornerLimit ?? _cornerLimit,
                              spread: false,
                              paperColor: _paperColor,
                              pixelRatio: View.of(context).devicePixelRatio,
                            )
                          : CurlPainter(
                              mesh: _mesh,
                              opaquePages: _opaqueReference,
                              images: images,
                              progress: progress,
                              grabY: pose?.grabY ?? _grabY,
                              tilt: pose?.tilt ?? _tilt,
                              cornerWeight: pose?.cornerWeight ?? _cornerWeight,
                              horizontalWeight:
                                  pointerPose?.horizontalWeight ??
                                  _horizontalWeight,
                              diagonalWeight:
                                  pointerPose?.diagonalWeight ??
                                  _diagonalWeight,
                              cornerLimit: pose?.cornerLimit ?? _cornerLimit,
                              spread: false,
                              paperColor: _paperColor,
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeTimingsCallback(_onTimings);
    _animation.dispose();
    _shader.dispose();
    for (final image in widget.images) {
      image.dispose();
    }
    super.dispose();
  }
}
