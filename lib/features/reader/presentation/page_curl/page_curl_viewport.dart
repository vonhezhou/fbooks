import 'dart:async';
import 'dart:ui' as ui;

import 'package:fbooks/features/reader/presentation/page_curl/curl_drag.dart';
import 'package:fbooks/features/reader/presentation/page_curl/curl_motion.dart';
import 'package:fbooks/features/reader/presentation/page_curl/curl_painter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// 一个手势独占两张有界页面纹理；加载、取消和卸载都必须释放所有权。
class CurlTurnPages {
  CurlTurnPages({required this.current, required this.target});
  final ui.Image current, target;

  void dispose() {
    current.dispose();
    target.dispose();
  }
}

class PageCurlViewport extends StatefulWidget {
  const PageCurlViewport({
    super.key,
    required this.revision,
    required this.paperColor,
    required this.prepareTurn,
    required this.onTurn,
    required this.child,
  });

  final Object revision;
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
  }

  @override
  void didUpdateWidget(PageCurlViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _reset();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      setState(_reset);
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
    _tracker.reset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      _direction = delta.dx < 0 ? 1 : -1;
      unawaited(_prepare());
    }
    if (_pages != null) _applyPose();
  }

  Future<void> _prepare() async {
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
      _applyPose();
      // 加载期间松手的手势必须取消，不能稍后擅自翻页。
      if (!_dragging) await _finish(null);
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
    setState(() {
      _pose = _takeover != null
          ? continueCurlDrag(_size, _takeover!, _point - _origin)
          : _direction > 0
          ? resolveForwardCurlDrag(_size, _origin, _point)
          : resolveBackwardCurlDrag(_size, _origin, _point);
    });
    _tracker.add(_pose!, _stamp);
  }

  Future<void> _finish(double? velocity) async {
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
    final releaseVelocity = stale ? 0.0 : velocity;
    final target = releaseVelocity == null || _canceled
        ? initial
        : settleTarget(
            _takeover != null
                ? _pose!.progress
                : dragProgress(initial, _point.dx - _origin.dx, _size.width),
            releaseVelocity,
            _size.width,
          );
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
          size: _size,
        );
        await _animation.animateWith(_release!).orCancel;
      }
      if (!mounted || token != _token) return;
      setState(_reset);
      if (commit) widget.onTurn(direction);
    } on TickerCanceled {
      // 新手势或排版变化已接管；旧收尾不再有提交位置的权利。
    }
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
        onPointerDown: (event) {
          if (!_dragging && !_loading) {
            _pointer = event.pointer;
            if (_release == null) _origin = event.localPosition;
          }
        },
        onPointerUp: (event) {
          if (event.pointer == _pointer) _stamp = event.timeStamp;
        },
        onPointerCancel: (event) {
          if (event.pointer == _pointer) {
            _canceled = true;
            _stamp = event.timeStamp;
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: _start,
          onHorizontalDragUpdate: _update,
          onHorizontalDragEnd: (details) =>
              unawaited(_finish(details.primaryVelocity ?? 0)),
          onHorizontalDragCancel: () => unawaited(_finish(null)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (pages != null && pose != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        key: const Key('reader-page-curl'),
                        painter: CurlPainter(
                          images: _direction > 0
                              ? [pages.current, pages.target]
                              : [pages.target, pages.current],
                          progress: pose.progress,
                          grabY: pose.grabY,
                          tilt: pose.tilt,
                          cornerWeight: pose.cornerWeight,
                          horizontalWeight: pose.horizontalWeight,
                          diagonalWeight: pose.diagonalWeight,
                          cornerLimit: pose.cornerLimit,
                          spread: false,
                          opaquePages: true,
                          mesh: _mesh,
                          paperColor: widget.paperColor,
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
