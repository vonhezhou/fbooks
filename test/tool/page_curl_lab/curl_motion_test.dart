import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/curl_drag.dart';
import '../../../tool/page_curl_lab/curl_motion.dart';
import '../../../tool/page_curl_lab/curl_geometry.dart';

void main() {
  const size = Size(390, 844);
  const start = CurlDragPose(.35, .8, .7, .6, 373, .2, .3, .5);

  test('释放承接实际纸面进度和形变速度，目标相同也不会套用相同缓动', () {
    final motion = CurlReleaseMotion(
      start: start,
      target: 1,
      size: size,
      velocity: const CurlPoseVelocity(
        progress: .9,
        tilt: .4,
        cornerLimit: -.2,
      ),
    );
    expect(motion.x(0), start.progress);
    expect(motion.dx(0), .9);
    const dt = 1e-7;
    final next = motion.poseAt(dt);
    expect((next.progress - start.progress) / dt, closeTo(.9, .0001));
    expect((next.tilt - start.tilt) / dt, closeTo(.4, .0001));
    expect((next.cornerLimit - start.cornerLimit) / dt, closeTo(-.2, .0001));
    final still = CurlReleaseMotion(
      start: start,
      velocity: const CurlPoseVelocity(),
      target: 1,
      size: size,
    );
    expect((motion.x(.02) - still.x(.02)).abs(), greaterThan(.005));
  });

  test('快速甩页与反向释放均不越界，收尾准确到达端点且速度归零', () {
    for (final p in [0.0, .001, .15, .5, .99, 1.0]) {
      for (final v in [-12.0, -.5, 0.0, .5, 12.0]) {
        for (final target in [0.0, 1.0]) {
          final motion = CurlReleaseMotion(
            start: CurlDragPose(p, .8, 1, 1, 373, 0, 0, 1),
            velocity: CurlPoseVelocity(progress: v),
            target: target,
            size: size,
          );
          for (var i = 0; i <= 240; i++) {
            expect(
              motion.x(i / 200),
              inInclusiveRange(-1e-12, 1 + 1e-12),
              reason: 'p=$p v=$v target=$target t=${i / 200}',
            );
            expect(motion.dx(i / 200).isFinite, isTrue);
          }
          expect(motion.isDone(1.2), isTrue);
          expect(motion.x(1.2), target);
          expect(motion.dx(1.2), 0);
        }
      }
    }
  });

  test('记录真实姿态速度，停驻或重新抓取后不继承旧速度', () {
    final tracker = CurlMotionTracker();
    for (var i = 0; i <= 4; i++) {
      tracker.add(
        CurlDragPose(.1 + i * .01, .8, i * .02, 1, 373, 0),
        Duration(milliseconds: i * 20),
      );
    }
    final velocity = tracker.velocityAt(const Duration(milliseconds: 80));
    expect(velocity.progress, closeTo(.5, 1e-10));
    expect(velocity.tilt, closeTo(1, 1e-10));
    expect(tracker.velocityAt(const Duration(milliseconds: 200)).progress, 0);
    tracker.reset();
    tracker.add(start, const Duration(milliseconds: 220));
    expect(tracker.velocityAt(const Duration(milliseconds: 220)).progress, 0);
  });

  test('到达形变上限后纸面静止，不把仍移动的指针速度注入纸面', () {
    final tracker = CurlMotionTracker();
    for (var i = 0; i < 5; i++) {
      tracker.add(start, Duration(milliseconds: i * 16));
    }
    final velocity = tracker.velocityAt(const Duration(milliseconds: 64));
    expect(velocity.progress, closeTo(0, 1e-10));
    expect(velocity.tilt, closeTo(0, 1e-10));
    final release = CurlReleaseMotion(
      start: start,
      velocity: velocity,
      target: 0,
      size: size,
    );
    expect(release.dx(0), closeTo(0, 1e-10));
  });
  test('释放前后真实材料点的屏幕速度与深度速度连续', () {
    const dt = 1e-7;
    CurlGeometry geometry(CurlDragPose pose) => CurlGeometry(
      size: size,
      progress: pose.progress,
      grabY: pose.grabY,
      tilt: pose.tilt,
      cornerWeight: pose.cornerWeight,
      horizontalWeight: pose.horizontalWeight,
      diagonalWeight: pose.diagonalWeight,
      cornerLimit: pose.cornerLimit,
    );
    const velocity = CurlPoseVelocity(
      progress: .8,
      grabY: .1,
      tilt: -.2,
      cornerWeight: -.3,
      horizontalWeight: .2,
      diagonalWeight: -.1,
      cornerLimit: -.2,
    );
    final before = geometry(
      CurlDragPose(
        start.progress - .8 * dt,
        start.grabY - .1 * dt,
        start.tilt + .2 * dt,
        start.cornerWeight + .3 * dt,
        start.controlX,
        start.horizontalWeight - .2 * dt,
        start.diagonalWeight + .1 * dt,
        start.cornerLimit + .2 * dt,
      ),
    );
    final current = geometry(start);
    for (final target in [0.0, 1.0]) {
      final motion = CurlReleaseMotion(
        start: start,
        velocity: velocity,
        target: target,
        size: size,
      );
      final after = geometry(motion.poseAt(dt));
      for (final fx in [.25, .6, 1.0]) {
        for (final fy in [.1, .5, .9]) {
          final a = before.project(size.width * fx, size.height * fy);
          final b = current.project(size.width * fx, size.height * fy);
          final c = after.project(size.width * fx, size.height * fy);
          expect(
            ((c.position - b.position) / dt - (b.position - a.position) / dt)
                .distance,
            lessThan(.15),
          );
          expect(
            ((c.depth - b.depth) - (b.depth - a.depth)).abs() / dt,
            lessThan(.15),
          );
        }
      }
    }
  });

  test('只有真实纸面接近平面且速度衰减后才提交端点', () {
    for (final initial in [start, const CurlDragPose(.5, .5, 0, 0, 373, 1)]) {
      for (final target in [0.0, 1.0]) {
        final motion = CurlReleaseMotion(
          start: initial,
          velocity: const CurlPoseVelocity(),
          target: target,
          size: size,
        );
        var t = 0.0;
        while (!motion.isDone(t) && t < 2) {
          t += 1 / 240;
        }
        expect(t, lessThan(2));
        final near = motion.poseAt(t - 1 / 240);
        final g = CurlGeometry(
          size: size,
          progress: near.progress,
          grabY: near.grabY,
          tilt: near.tilt,
          cornerWeight: near.cornerWeight,
          horizontalWeight: near.horizontalWeight,
          diagonalWeight: near.diagonalWeight,
          cornerLimit: near.cornerLimit,
        );
        for (final y in [0.0, size.height * .5, size.height]) {
          final v = g.project(size.width, y);
          expect(
            (v.position - Offset(target == 0 ? size.width : -size.width, y))
                .distance,
            lessThan(.3),
          );
          expect(v.depth.abs(), lessThan(.3));
        }
      }
    }
  });
}
