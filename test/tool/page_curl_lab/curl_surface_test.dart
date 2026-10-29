import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/curl_geometry.dart';

List<double> materialPoint(CurlGeometry g, double x, double y) {
  final v = g.project(x, y);
  final scale =
      1 -
      v.depth /
          (g.size.width *
              curlCameraScaleForCorner(
                g.cornerWeight ?? curlCornerWeightForGrab(g.grabY),
                horizontalWeight: g.horizontalWeight,
              ));
  return [
    v.position.dx * scale,
    (v.position.dy - g.size.height / 2) /
            curlVerticalProjectionScale(1 / scale, g.verticalProjectionWeight) +
        g.size.height / 2,
    v.depth,
  ];
}

void main() {
  test('所有混合权重保持三维材料长度和正交性，固定整条书脊', () {
    var maxStrain = 0.0, maxShear = 0.0;
    for (final size in [
      const Size(390, 844),
      const Size(600, 800),
      const Size(960, 720),
    ]) {
      for (final p in [.01, .05, .15, .33, .5, .75, .95, .99]) {
        for (final grab in [.13, .5, .87]) {
          for (final tilt in [-2.0, -.5, 0.0, .5, 2.0]) {
            for (final limit in [-1.0, -.5, -.1, 0.0, .1, .5, 1.0]) {
              final g = CurlGeometry(
                size: size,
                progress: p,
                grabY: grab,
                tilt: tilt,
                cornerWeight: curlCornerWeightForGrab(grab),
                cornerLimit: limit,
              );
              final context = '$size p=$p grab=$grab tilt=$tilt limit=$limit';
              for (final fy in [.1, .5, .9]) {
                final y = size.height * fy;
                final spine = materialPoint(g, 0, y);
                expect(spine[0], closeTo(0, 1e-7), reason: context);
                expect(spine[1], closeTo(y, 1e-7), reason: context);
                expect(spine[2], closeTo(0, 1e-7), reason: context);
                for (final fx in [.1, .5, .9]) {
                  final x = size.width * fx;
                  final h = math.min(.01, g.prepareRow(y).radius * .001);
                  final xa = materialPoint(g, x - h, y),
                      xb = materialPoint(g, x + h, y);
                  final ya = materialPoint(g, x, y - h),
                      yb = materialPoint(g, x, y + h);
                  final dx = [
                    for (var i = 0; i < 3; i++) (xb[i] - xa[i]) / (2 * h),
                  ];
                  final dy = [
                    for (var i = 0; i < 3; i++) (yb[i] - ya[i]) / (2 * h),
                  ];
                  double dot(List<double> a, List<double> b) =>
                      a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
                  final strain = math.max(
                    (math.sqrt(dot(dx, dx)) - 1).abs(),
                    (math.sqrt(dot(dy, dy)) - 1).abs(),
                  );
                  final shear = dot(dx, dy).abs();
                  maxStrain = math.max(maxStrain, strain);
                  maxShear = math.max(maxShear, shear);
                  expect(
                    strain,
                    lessThan(.001),
                    reason: '$context x=$fx y=$fy',
                  );
                  expect(shear, lessThan(.001), reason: '$context x=$fx y=$fy');
                }
              }
            }
          }
        }
      }
    }
    // 实测数值误差，便于评估模型而非只判断有限值。
    // ignore: avoid_print
    print('material metric: max strain=$maxStrain max shear=$maxShear');
  });
  test('曲面混合穿过圆柱极限时位置和光照连续，端点整张归平', () {
    const size = Size(390, 844);
    for (final grab in [.13, .5, .87]) {
      for (final p in [.05, .33, .75, .95]) {
        CurlGeometry g(double tilt, double limit, {double horizontal = 0}) =>
            CurlGeometry(
              size: size,
              progress: p,
              grabY: grab,
              tilt: tilt,
              cornerWeight: 0,
              horizontalWeight: horizontal,
              cornerLimit: limit,
            );
        for (final horizontal in [0.0, 1.0]) {
          final center = g(0, 0, horizontal: horizontal);
          for (final sign in [-1.0, 1.0]) {
            final near = g(sign * 1e-7, 0, horizontal: horizontal);
            for (final y in [0.0, size.height * .5, size.height]) {
              for (final x in [size.width * .5, size.width]) {
                final a = center.project(x, y), b = near.project(x, y);
                expect((a.position - b.position).distance, lessThan(.001));
                expect((a.depth - b.depth).abs(), lessThan(.001));
                expect((a.light - b.light).abs(), lessThan(.001));
              }
            }
          }
        }
        // 混合上下相反的锥顶距离会穿过零值，不能突然切换上下页角。
        const tilt = -1.0;
        final samples = [for (var i = 0; i <= 1000; i++) g(tilt, i / 1000)];
        for (var i = 1; i < samples.length; i++) {
          final a = samples[i - 1].project(size.width, size.height * grab);
          final b = samples[i].project(size.width, size.height * grab);
          expect((a.position - b.position).distance, lessThan(8));
        }
      }
      for (final limit in [-1.0, -.5, 0.0, .5, 1.0]) {
        for (final end in [0.0, 1.0]) {
          final near = CurlGeometry(
            size: size,
            progress: end == 0 ? 1e-9 : 1 - 1e-9,
            grabY: grab,
            tilt: 1.5,
            cornerLimit: limit,
          );
          for (final y in [0.0, size.height * .5, size.height]) {
            final v = near.project(size.width, y);
            expect(
              (v.position - Offset(end == 0 ? size.width : -size.width, y))
                  .distance,
              lessThan(.02),
            );
            expect(v.depth.abs(), lessThan(.02));
          }
        }
      }
    }
  });
}
