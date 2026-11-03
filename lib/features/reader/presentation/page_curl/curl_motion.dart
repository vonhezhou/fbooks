import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/physics.dart';

import 'package:fbooks/features/reader/presentation/page_curl/curl_drag.dart';
import 'package:fbooks/features/reader/presentation/page_curl/curl_geometry.dart';

class CurlPoseVelocity {
  const CurlPoseVelocity({
    this.progress = 0,
    this.grabY = 0,
    this.tilt = 0,
    this.cornerWeight = 0,
    this.horizontalWeight = 0,
    this.diagonalWeight = 0,
    this.cornerLimit = 0,
  });

  final double progress, grabY, tilt, cornerWeight;
  final double horizontalWeight, diagonalWeight, cornerLimit;

  List<double> get _values => [
    progress,
    grabY,
    tilt,
    cornerWeight,
    horizontalWeight,
    diagonalWeight,
    cornerLimit,
  ];
}

List<double> _values(CurlDragPose pose) => [
  pose.progress,
  pose.grabY,
  pose.tilt,
  pose.cornerWeight,
  pose.horizontalWeight,
  pose.diagonalWeight,
  pose.cornerLimit,
];

// 用实际显示姿态而非线性指针距离估计速度。卷曲上限处指针仍可能移动，
// 纸面已静止，此时不能把指针速度再次注入纸面。
class CurlMotionTracker {
  final _samples = <({double time, CurlDragPose pose})>[];

  void reset() => _samples.clear();

  void add(CurlDragPose pose, Duration? stamp) {
    if (stamp == null) return;
    final time = stamp.inMicroseconds / 1000000;
    if (_samples.isNotEmpty && time < _samples.last.time) reset();
    if (_samples.isNotEmpty && time == _samples.last.time) {
      _samples.removeLast();
    }
    _samples.add((time: time, pose: pose));
    while (_samples.length > 12 ||
        (_samples.length > 2 && time - _samples.first.time > .08)) {
      _samples.removeAt(0);
    }
  }

  CurlPoseVelocity velocityAt(Duration? stamp) {
    if (stamp == null || _samples.length < 2) return const CurlPoseVelocity();
    final age = stamp.inMicroseconds / 1000000 - _samples.last.time;
    // 停驻后释放不继承上一次拖动的陈旧速度。
    if (age < 0 || age > .06) return const CurlPoseVelocity();
    final origin = _samples.first.time;
    final times = [for (final sample in _samples) sample.time - origin];
    final mean = times.reduce((a, b) => a + b) / times.length;
    final denominator = times.fold(
      0.0,
      (sum, t) => sum + (t - mean) * (t - mean),
    );
    if (denominator < 1e-12) return const CurlPoseVelocity();
    final slopes = List<double>.filled(7, 0);
    for (var i = 0; i < _samples.length; i++) {
      final values = _values(_samples[i].pose);
      for (var j = 0; j < slopes.length; j++) {
        slopes[j] += (times[i] - mean) * values[j] / denominator;
      }
    }
    return CurlPoseVelocity(
      progress: slopes[0],
      grabY: slopes[1],
      tilt: slopes[2],
      cornerWeight: slopes[3],
      horizontalWeight: slopes[4],
      diagonalWeight: slopes[5],
      cornerLimit: slopes[6],
    );
  }
}

// 临界阻尼的解析解：起点和速度连续。根据可用距离提高阻尼频率，
// 防止高速释放越出边界，而不是逐帧 clamp 后突然截断速度。
class _DampedChannel {
  _DampedChannel(
    this.start,
    this.target,
    double velocity,
    double low,
    double high,
  ) {
    if ((start <= low && velocity < 0) || (start >= high && velocity > 0)) {
      velocity = 0;
    }
    v = velocity;
    final distance = (target - start).abs();
    final toward = velocity * (target - start).sign;
    omega = 26;
    if (distance > 0 && toward > 0) omega = math.max(omega, toward / distance);
    final room = velocity >= 0 ? high - start : start - low;
    if (room > 0) omega = math.max(omega, velocity.abs() / (math.e * room));
    a = start - target;
    b = velocity + omega * a;
  }

  final double start, target;
  late final double v, a, b;
  late double omega;

  double x(double t) => target + (a + b * t) * math.exp(-omega * t);
  double dx(double t) => (v - omega * b * t) * math.exp(-omega * t);
}

class CurlReleaseMotion extends Simulation {
  CurlReleaseMotion({
    required this.start,
    required CurlPoseVelocity velocity,
    required this.target,
    required this.size,
  }) : assert(target == 0 || target == 1),
       _pixelScale = 2 * math.max(size.width, size.height) {
    final positions = _values(start), speeds = velocity._values;
    final lows = [
      0.0,
      0.0,
      -2.0,
      0.0,
      0.0,
      0.0,
      start.cornerLimit < 0 ? -1.0 : 0.0,
    ];
    final highs = [
      1.0,
      1.0,
      2.0,
      1.0,
      1.0,
      1.0,
      start.cornerLimit > 0 ? 1.0 : 0.0,
    ];
    for (var i = 0; i < positions.length; i++) {
      _channels.add(
        _DampedChannel(
          positions[i],
          i == 0 ? target : positions[i],
          speeds[i],
          lows[i],
          highs[i],
        ),
      );
    }
  }

  final CurlDragPose start;
  final Size size;
  final double target, _pixelScale;
  double? _checkedTime;
  bool _done = false;
  final _channels = <_DampedChannel>[];

  CurlDragPose poseAt(double time) {
    return _pose(time, done: isDone(time));
  }

  CurlDragPose _pose(double time, {bool done = false}) {
    final values = [
      for (final channel in _channels) done ? channel.target : channel.x(time),
    ];
    return CurlDragPose(
      values[0],
      values[1],
      values[2],
      values[3],
      start.controlX,
      values[4],
      values[5],
      values[6],
    );
  }

  @override
  double x(double time) => isDone(time) ? target : _channels[0].x(time);

  @override
  double dx(double time) => isDone(time) ? 0 : _channels[0].dx(time);

  @override
  bool isDone(double time) {
    if (_checkedTime == time) return _done;
    _checkedTime = time;
    if (_channels[0].x(time) == target && _channels[0].dx(time) == 0) {
      return _done = true;
    }
    if (!_channels.every(
      (channel) =>
          (channel.x(time) - channel.target).abs() * _pixelScale < .25 &&
          channel.dx(time).abs() * _pixelScale < 2,
    )) {
      return _done = false;
    }
    CurlGeometry geometry(double t) {
      final pose = _pose(t);
      return CurlGeometry(
        size: size,
        progress: pose.progress,
        grabY: pose.grabY,
        tilt: pose.tilt,
        cornerWeight: pose.cornerWeight,
        horizontalWeight: pose.horizontalWeight,
        diagonalWeight: pose.diagonalWeight,
        cornerLimit: pose.cornerLimit,
      );
    }

    // 参数接近端点不代表弯曲带已经不可见。按真实材料点的投影、深度及
    // 运动速度判断收尾，避免最后一帧突然把仍抬起的纸面压平。
    const dt = .0001;
    final current = geometry(time), next = geometry(time + dt);
    for (final y in [0.0, size.height * start.grabY, size.height]) {
      final row = current.prepareRow(y), after = next.prepareRow(y);
      for (final x in [size.width * .5, size.width]) {
        final p = row.project(x), q = after.project(x);
        final end = Offset(target == 0 ? x : -x, y);
        if ((p.position - end).distance > .25 ||
            p.depth.abs() > .25 ||
            (q.position - p.position).distance / dt > 2 ||
            (q.depth - p.depth).abs() / dt > 2) {
          return _done = false;
        }
      }
    }
    return _done = true;
  }
}
