import 'dart:async';
import 'dart:ui' as ui;

import 'package:fbooks/features/reader/presentation/page_curl/curl_drag.dart';
import 'package:fbooks/features/reader/presentation/page_curl/curl_motion.dart';
import 'package:fbooks/features/reader/presentation/page_curl/curl_painter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// 一个手势持有单页／双页卷曲贴图及可选落页图，取消和卸载时统一释放。
class CurlTurnPages {
  CurlTurnPages({
    required ui.Image current,
    required ui.Image target,
    this.onCommit,
    this.paperBounds,
    this.landingImage,
  }) : images = [current, target],
       spread = false;
  CurlTurnPages.spread(
    List<ui.Image> faces, {
    this.onCommit,
    this.paperBounds,
    this.landingImage,
  }) : images = List.unmodifiable(faces),
       spread = true {
    if (images.length != 4) throw ArgumentError('A spread requires four faces');
  }
  final List<ui.Image> images;
  final bool spread;
  final VoidCallback? onCommit;
  final Rect? paperBounds;
  // 与卷曲贴图一起持有，取消时释放，提交时通过 clone 交接给静止页。
  final ui.Image? landingImage;
  ui.Image get current => images[0];
  ui.Image get target => images[1];

  void dispose() {
    for (final image in images) {
      image.dispose();
    }
    landingImage?.dispose();
  }
}

class PageCurlController {
  _PageCurlViewportState? _state;
  Future<void> turn(int direction) async => _state?._turn(direction);
}

class PageCurlViewport extends StatefulWidget {
  const PageCurlViewport({
    super.key,
    required this.revision,
    required this.paperColor,
    required this.prepareTurn,
    required this.onTurn,
    required this.child,
    this.enabled = true,
    this.rtl = false,
    this.rawDrag = false,
    this.controller,
  });

  final Object revision;
  final bool enabled;
  final bool rtl, rawDrag;
  final PageCurlController? controller;
  final Color paperColor;
  final Future<CurlTurnPages?> Function(int direction) prepareTurn;
  final ValueChanged<int> onTurn;
  final Widget child;

  @override
  State<PageCurlViewport> createState() => _PageCurlViewportState();
}

class _PageCurlViewportState extends State<PageCurlViewport>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _animation = AnimationController.unbounded(vsync: this)
    ..addListener(_tick);
  final _tracker = CurlMotionTracker();
  final _mesh = CurlMesh();
  final _rawPointers = <int>{};
  VelocityTracker? _rawVelocity;
  bool _activeRaw = false;
  Rect get _paperBounds => _pages?.paperBounds ?? Offset.zero & _size;
  Size get _paperSize => Size(
    _paperBounds.width / (_pages?.spread == true ? 2 : 1),
    _paperBounds.height,
  );
  double get _logicalDelta => (_point.dx - _origin.dx) * (widget.rtl ? -1 : 1);
  CurlTurnPages? _pages;
  CurlReleaseMotion? _release;
  CurlDragPose? _pose, _takeover;
  Offset _origin = Offset.zero, _point = Offset.zero;
  Size _size = Size.zero;
  Duration? _stamp, _lastMoveStamp;
  int _direction = 0, _token = 0;
  int? _pointer;
  bool _canceled = false;
  bool _dragging = false, _loading = false;
  double _slop = kTouchSlop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(PageCurlViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
    if (oldWidget.revision != widget.revision ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.rtl != widget.rtl) {
      _reset();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      setState(() {
        _rawPointers.clear();
        _activeRaw = false;
        _reset();
      });
    }
  }

  void _reset() {
    _token++;
    _animation.stop();
    _release = null;
    _pages?.dispose();
    _pages = null;
    _pose = _takeover = null;
    _direction = 0;
    _dragging = _loading = false;
    _activeRaw = false;
    _tracker.reset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?._state = null;
    _reset();
    _animation.dispose();
    super.dispose();
  }

  void _tick() {
    if (_release case final motion?) {
      setState(() {
        _pose = motion.poseAt(
          (_animation.lastElapsedDuration ?? Duration.zero).inMicroseconds /
              1000000,
        );
      });
    }
  }

  void _start(DragStartDetails details) {
    if (_loading) return;
    final reserved = MediaQuery.systemGestureInsetsOf(context);
    final globalX = details.globalPosition.dx;
    if (_release == null &&
        (globalX < reserved.left ||
            globalX > MediaQuery.sizeOf(context).width - reserved.right)) {
      _dragging = false;
      return;
    }
    _slop = computeHitSlop(
      details.kind ?? ui.PointerDeviceKind.touch,
      MediaQuery.gestureSettingsOf(context),
    );
    _tracker.reset();
    _stamp = _lastMoveStamp = details.sourceTimeStamp;
    _dragging = true;
    _canceled = false;
    if (_release != null) {
      _takeover = _pose;
      _origin = details.localPosition;
      _token++;
      _animation.stop();
      _release = null;
      _tracker.add(_pose!, details.sourceTimeStamp);
    } else {
      _takeover = null;
    }
    _point = details.localPosition;
  }

  void _update(DragUpdateDetails details) {
    if (!_dragging) return;
    _point = details.localPosition;
    _stamp = _lastMoveStamp = details.sourceTimeStamp;
    if (_direction == 0) {
      final delta = _point - _origin;
      if (delta.distance < _slop) return;
      if (!curlDragHasHorizontalIntent(delta)) {
        _dragging = false;
        return;
      }
      _direction = _logicalDelta < 0 ? 1 : -1;
      unawaited(_prepare());
    }
    if (_pages != null) _applyPose();
  }

  Future<void> _turn(int direction) async {
    if (!widget.enabled ||
        _loading ||
        _dragging ||
        _release != null ||
        direction.abs() != 1) {
      return;
    }
    _direction = direction;
    _canceled = false;
    _tracker.reset();
    await _prepare(forcedTarget: direction > 0 ? 1 : 0);
  }

  Future<void> _prepare({double? forcedTarget}) async {
    final token = ++_token;
    _loading = true;
    CurlTurnPages? pages;
    try {
      pages = await widget.prepareTurn(_direction);
      if (!mounted || token != _token) {
        pages?.dispose();
        return;
      }
      _loading = false;
      if (pages == null) {
        setState(_reset);
        return;
      }
      _pages = pages;
      if (forcedTarget != null) {
        setState(
          () => _pose = CurlDragPose(
            _direction > 0 ? 0 : 1,
            .5,
            0,
            0,
            _paperSize.width,
            1,
          ),
        );
        await _finish(null, forcedTarget: forcedTarget);
      } else {
        _applyPose();
        // 加载期间松手的手势必须取消，不能稍后擅自翻页。
        if (!_dragging) await _finish(null);
      }
    } catch (_) {
      pages?.dispose();
      if (mounted && token == _token) {
        // 页面准备失败保留原来的可交互正文；下一次操作可以重试。
        _pages = null;
        setState(_reset);
      }
    }
  }

  void _applyPose() {
    final spread = _pages?.spread == true;
    final original = curlPagePoint(
      _paperBounds.size,
      _origin - _paperBounds.topLeft,
      spread: spread,
      rtl: widget.rtl,
    );
    var origin = original;
    var point = curlPagePoint(
      _paperBounds.size,
      _point - _paperBounds.topLeft,
      spread: spread,
      rtl: widget.rtl,
    );
    // 从固定侧起手仍可翻页，以自由边为控制点施加相同位移。
    if (spread && (_direction > 0 ? origin.dx <= 0 : origin.dx >= 0)) {
      origin = Offset(
        _direction > 0 ? _paperSize.width : -_paperSize.width,
        origin.dy,
      );
      point = origin + (point - original);
    }
    setState(() {
      _pose = _takeover != null
          ? continueCurlDrag(_paperSize, _takeover!, point - origin)
          : _direction > 0
          ? resolveForwardCurlDrag(_paperSize, origin, point)
          : resolveBackwardCurlDrag(_paperSize, origin, point, spread: spread);
    });
    _tracker.add(_pose!, _stamp);
  }

  Future<void> _finish(double? velocity, {double? forcedTarget}) async {
    // 识别器可能先于外层 Listener 收到 up；等同一事件分发结束再读取释放时间。
    await Future<void>.value();
    if (!mounted) return;
    _dragging = false;
    if (_loading || _pages == null) return;
    final token = ++_token;
    final initial = _direction > 0 ? 0.0 : 1.0;
    final stale =
        _stamp != null &&
        _lastMoveStamp != null &&
        (_stamp! - _lastMoveStamp!).inMilliseconds > 60;
    final releaseVelocity = stale
        ? 0.0
        : velocity == null
        ? null
        : velocity * (widget.rtl ? -1 : 1);
    final target =
        forcedTarget ??
        (releaseVelocity == null || _canceled
            ? initial
            : settleTarget(
                _takeover != null
                    ? _pose!.progress
                    : dragProgress(initial, _logicalDelta, _paperSize.width),
                releaseVelocity,
                _paperSize.width,
              ));
    final commit = _direction > 0 ? target == 1 : target == 0;
    final direction = _direction;
    try {
      if (!MediaQuery.disableAnimationsOf(context)) {
        _release = CurlReleaseMotion(
          start: _pose!,
          velocity: velocity == null
              ? const CurlPoseVelocity()
              : _tracker.velocityAt(_stamp),
          target: target,
          size: _paperSize,
        );
        await _animation.animateWith(_release!).orCancel;
      }
      if (!mounted || token != _token) return;
      if (commit) _pages?.onCommit?.call();
      setState(_reset);
      if (commit) widget.onTurn(direction);
    } on TickerCanceled {
      // 新手势或排版变化已接管；旧收尾不再有提交位置的权利。
    }
  }

  void _pointerDown(PointerDownEvent event) {
    if (widget.rawDrag &&
        event.kind == ui.PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }
    if (widget.rawDrag) {
      _rawPointers.add(event.pointer);
      if (_rawPointers.length > 1) {
        _activeRaw = false;
        _canceled = true;
        unawaited(_finish(null));
        return;
      }
    }
    if (!_dragging && !_loading) {
      _pointer = event.pointer;
      if (_release == null) _origin = event.localPosition;
    }
    if (widget.rawDrag && widget.enabled) {
      _activeRaw = true;
      _rawVelocity = VelocityTracker.withKind(event.kind)
        ..addPosition(event.timeStamp, event.localPosition);
      _start(
        DragStartDetails(
          sourceTimeStamp: event.timeStamp,
          globalPosition: event.position,
          localPosition: event.localPosition,
          kind: event.kind,
        ),
      );
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    if (_rawPointers.length != 1 ||
        event.pointer != _pointer ||
        !widget.enabled) {
      return;
    }
    _rawVelocity?.addPosition(event.timeStamp, event.localPosition);
    _update(
      DragUpdateDetails(
        sourceTimeStamp: event.timeStamp,
        delta: event.delta,
        globalPosition: event.position,
        localPosition: event.localPosition,
      ),
    );
  }

  void _pointerUp(PointerUpEvent event) {
    _rawPointers.remove(event.pointer);
    if (event.pointer != _pointer) return;
    _stamp = event.timeStamp;
    if (widget.rawDrag && _activeRaw) {
      _activeRaw = false;
      unawaited(_finish(_rawVelocity?.getVelocity().pixelsPerSecond.dx ?? 0));
    }
  }

  void _pointerCancel(PointerCancelEvent event) {
    _rawPointers.remove(event.pointer);
    if (event.pointer != _pointer) return;
    _canceled = true;
    _stamp = event.timeStamp;
    if (widget.rawDrag && _activeRaw) {
      _activeRaw = false;
      unawaited(_finish(null));
    }
  }

  void _panZoomStart(PointerPanZoomStartEvent event) {
    if (!widget.enabled || _loading) return;
    _pointer = event.pointer;
    _origin = event.localPosition;
    _activeRaw = true;
    _rawVelocity = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, _origin);
    _start(
      DragStartDetails(
        sourceTimeStamp: event.timeStamp,
        globalPosition: event.position,
        localPosition: event.localPosition,
        kind: event.kind,
      ),
    );
  }

  void _panZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (!_activeRaw || event.pointer != _pointer || !widget.enabled) return;
    if ((event.scale - 1).abs() > .001) {
      _activeRaw = false;
      _canceled = true;
      unawaited(_finish(null));
      return;
    }
    final position = event.localPosition + event.localPan;
    _rawVelocity?.addPosition(event.timeStamp, position);
    _update(
      DragUpdateDetails(
        sourceTimeStamp: event.timeStamp,
        delta: event.localPanDelta,
        globalPosition: event.position + event.pan,
        localPosition: position,
      ),
    );
  }

  void _panZoomEnd(PointerPanZoomEndEvent event) {
    if (!_activeRaw || event.pointer != _pointer) return;
    _activeRaw = false;
    _stamp = event.timeStamp;
    unawaited(_finish(_rawVelocity?.getVelocity().pixelsPerSecond.dx ?? 0));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (_size != size) {
        _reset();
        _size = size;
      }
      final pages = _pages, pose = _pose;
      return Listener(
        onPointerDown: _pointerDown,
        onPointerMove: widget.rawDrag ? _pointerMove : null,
        onPointerUp: _pointerUp,
        onPointerCancel: _pointerCancel,
        onPointerPanZoomStart: _panZoomStart,
        onPointerPanZoomUpdate: _panZoomUpdate,
        onPointerPanZoomEnd: _panZoomEnd,
        child: GestureDetector(
          supportedDevices: const {
            ui.PointerDeviceKind.touch,
            ui.PointerDeviceKind.mouse,
            ui.PointerDeviceKind.stylus,
            ui.PointerDeviceKind.invertedStylus,
          },
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: widget.enabled && !widget.rawDrag
              ? _start
              : null,
          onHorizontalDragUpdate: widget.enabled && !widget.rawDrag
              ? _update
              : null,
          onHorizontalDragEnd: widget.enabled && !widget.rawDrag
              ? (details) => unawaited(_finish(details.primaryVelocity ?? 0))
              : null,
          onHorizontalDragCancel: widget.enabled && !widget.rawDrag
              ? () => unawaited(_finish(null))
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (pages != null && pose != null)
                Positioned.fromRect(
                  rect: _paperBounds,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: ClipRect(
                        clipBehavior: Clip.hardEdge,
                        child: CustomPaint(
                          key: const Key('reader-page-curl'),
                          painter: CurlPainter(
                            images: pages.spread
                                ? pages.images
                                : _direction > 0
                                ? [pages.current, pages.target]
                                : [pages.target, pages.current],
                            progress: pose.progress,
                            grabY: pose.grabY,
                            tilt: pose.tilt,
                            cornerWeight: pose.cornerWeight,
                            horizontalWeight: pose.horizontalWeight,
                            diagonalWeight: pose.diagonalWeight,
                            cornerLimit: pose.cornerLimit,
                            spread: pages.spread,
                            rtl: widget.rtl,
                            opaquePages: true,
                            batchOpaqueSpread:
                                defaultTargetPlatform == TargetPlatform.android,
                            mesh: _mesh,
                            paperColor: widget.paperColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
