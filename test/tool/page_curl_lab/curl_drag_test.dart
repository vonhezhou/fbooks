import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/curl_drag.dart';
import '../../../tool/page_curl_lab/curl_geometry.dart';

void main() {
  test('Books 起手边界接受水平及等斜拖，忽略竖直占优的新手势', () {
    expect(curlDragHasHorizontalIntent(Offset.zero), isTrue);
    for (final sign in [-1.0, 1.0]) {
      for (final ratio in [.5, .9, 1.0, 1.1, 1.5, 2.5]) {
        expect(
          curlDragHasHorizontalIntent(Offset(sign * 80, 80 * ratio)),
          ratio <= 1,
        );
      }
    }
  });

  Offset controlPoint(Size size, CurlDragPose pose) => CurlGeometry(
    size: size,
    progress: pose.progress,
    grabY: pose.grabY,
    tilt: pose.tilt,
    cornerWeight: pose.cornerWeight,
    horizontalWeight: pose.horizontalWeight,
    diagonalWeight: pose.diagonalWeight,
    cornerLimit: pose.cornerLimit,
  ).project(pose.controlX, size.height * pose.grabY).position;

  test('上下页角极端牵拉及接管保持有界，旧曲面抓点遵循书脊可达距离', () {
    for (final size in [const Size(390, 844), const Size(600, 800)]) {
      for (final grab in [0.0, .13, .87, 1.0]) {
        final origin = Offset(size.width * .956, size.height * grab);
        void reachable(CurlDragPose pose) {
          final material = Offset(pose.controlX, size.height * pose.grabY);
          final projected = controlPoint(size, pose);
          expect(projected.dx.abs(), lessThan(size.width * 2));
          expect(projected.dy, inInclusiveRange(-size.height, size.height * 2));
          // 混合阶段更换了有效抓取行，不把旧控制点的距离契约套在混合曲面上。
          // 完整对角极限的不可拉伸约束由几何层三维局部长度回归单独验证。
          if (pose.cornerLimit != 0) return;
          for (final spine in [Offset.zero, Offset(0, size.height)]) {
            expect(
              (projected - spine).distance,
              lessThanOrEqualTo((material - spine).distance + .01),
              reason: '$size grab=$grab point=$projected',
            );
          }
        }

        for (final fraction in [.001, .05, .2, .5, 1.0, 1.8, 2.5]) {
          for (final dy in [-4.0, -1.0, 1.0, 4.0]) {
            final delta = Offset(-size.width * fraction, size.height * dy);
            reachable(resolveForwardCurlDrag(size, origin, origin + delta));
            final backwardOrigin = Offset(size.width * .04, origin.dy);
            reachable(
              resolveBackwardCurlDrag(
                size,
                backwardOrigin,
                backwardOrigin + Offset(-delta.dx, delta.dy),
              ),
            );
            reachable(
              resolveBackwardCurlDrag(
                size,
                Offset(-origin.dx, origin.dy),
                Offset(-origin.dx - delta.dx, origin.dy + delta.dy),
                spread: true,
              ),
            );
            final start = resolveForwardCurlDrag(
              size,
              origin,
              origin + Offset(-size.width * .4, 0),
            );
            reachable(continueCurlDrag(size, start, delta));
          }
        }
      }
    }
  });

  test('超出页角可达上限后继续纵向拖动不会拉长，退回可恢复原姿态', () {
    const size = Size(390, 844);
    for (final grab in [.13, .87]) {
      final origin = Offset(373, size.height * grab);
      final held = origin + const Offset(-160, -30);
      final before = resolveForwardCurlDrag(size, origin, held);
      for (final sign in [-1.0, 1.0]) {
        final limit = resolveForwardCurlDrag(
          size,
          origin,
          Offset(213, origin.dy + sign * size.height * 2),
        );
        final beyond = resolveForwardCurlDrag(
          size,
          origin,
          Offset(213, origin.dy + sign * size.height * 4),
        );
        expect(controlPoint(size, beyond), controlPoint(size, limit));
        expect(beyond.progress, limit.progress);
        expect(beyond.tilt, limit.tilt);
        expect(beyond.cornerWeight, limit.cornerWeight);
        final backwardOrigin = Offset(17, origin.dy);
        final backward = resolveBackwardCurlDrag(
          size,
          backwardOrigin,
          Offset(177, origin.dy + sign * 1688),
        );
        final backwardBeyond = resolveBackwardCurlDrag(
          size,
          backwardOrigin,
          Offset(177, origin.dy + sign * 3376),
        );
        expect(
          controlPoint(size, backwardBeyond),
          controlPoint(size, backward),
        );

        final start = resolveForwardCurlDrag(
          size,
          origin,
          Offset(213, origin.dy),
        );
        final taken = continueCurlDrag(size, start, Offset(0, sign * 1688));
        final takenBeyond = continueCurlDrag(
          size,
          start,
          Offset(0, sign * 3376),
        );
        expect(controlPoint(size, takenBeyond), controlPoint(size, taken));
      }
      final after = resolveForwardCurlDrag(size, origin, held);
      expect(after.progress, before.progress);
      expect(after.tilt, before.tilt);
      expect(resolveForwardCurlDrag(size, origin, origin).progress, 0);
    }
  });

  test('强斜拖进入 Books 对角极限，阈值连续且饱和后仍可接管', () {
    const size = Size(390, 844), origin = Offset(373, 732);
    for (final direction in [-1.0, 1.0]) {
      for (final ratio in [.4, .7, 1.8, 2.0]) {
        final a = resolveForwardCurlDrag(
          size,
          origin,
          origin + Offset(-160, direction * 160 * (ratio - .000001)),
        );
        final b = resolveForwardCurlDrag(
          size,
          origin,
          origin + Offset(-160, direction * 160 * (ratio + .000001)),
        );
        expect(
          (controlPoint(size, a) - controlPoint(size, b)).distance,
          lessThan(.01),
        );
      }
      final start = resolveForwardCurlDrag(
        size,
        origin,
        origin + Offset(-160, direction * 640),
      );
      expect(start.cornerLimit, -direction);
      expect(continueCurlDrag(size, start, Offset.zero), same(start));
      final point = controlPoint(size, start);
      for (final delta in [
        const Offset(1, 0),
        const Offset(-1, 1),
        const Offset(0, -1),
      ]) {
        final after = continueCurlDrag(size, start, delta);
        expect(
          (controlPoint(size, after) - point - delta).distance,
          lessThan(.01),
        );
      }
    }
  });

  test('对角极限收尾的各阶段可反向接管，控制点不跳变', () {
    const size = Size(390, 844);
    for (final side in [-1.0, 1.0]) {
      for (final progress in [.12, .33, .55, .8]) {
        final start = CurlDragPose(
          progress,
          side > 0 ? .87 : .13,
          side,
          1,
          373,
          0,
          0,
          side,
        );
        final before = controlPoint(size, start);
        for (final delta in [const Offset(.1, 0), const Offset(-.1, .1)]) {
          final after = continueCurlDrag(size, start, delta);
          expect(
            (controlPoint(size, after) - before - delta).distance,
            lessThan(.01),
            reason: 'side=$side progress=$progress',
          );
        }
      }
    }
  });

  test('单页后翻起卷平滑建立自由边，页角也使用整页分类', () {
    const size = Size(390, 844), origin = Offset(17, 732);
    double edge(double dx) {
      final pose = resolveBackwardCurlDrag(
        size,
        origin,
        origin + Offset(dx, 0),
      );
      expect(pose.cornerWeight, 0);
      expect(pose.progress.isFinite, isTrue);
      return CurlGeometry(
        size: size,
        progress: pose.progress,
        grabY: pose.grabY,
        tilt: pose.tilt,
        cornerWeight: pose.cornerWeight,
        horizontalWeight: pose.horizontalWeight,
        diagonalWeight: pose.diagonalWeight,
      ).project(pose.controlX, origin.dy).position.dx;
    }

    expect(edge(0), -size.width);
    for (final dx in [.01, 1.0, 5.0, 10.0, 19.5, 30.0]) {
      final phase = (dx / 19.5).clamp(0.0, 1.0);
      final wanted =
          -390 + (17 + dx - 4 + 390) * phase * phase * (3 - 2 * phase);
      expect(edge(dx), closeTo(wanted, .001));
    }
    const e = .001, at = 19.5;
    expect(
      (edge(at) - edge(at - e)) / e,
      closeTo((edge(at + e) - edge(at)) / e, .02),
    );
    final inward = resolveBackwardCurlDrag(
      size,
      origin,
      const Offset(177, 668),
    );
    expect(inward.cornerWeight, 0);
    expect(inward.diagonalWeight, 1);
    final spread = resolveBackwardCurlDrag(
      size,
      const Offset(-373, 732),
      const Offset(-213, 668),
      spread: true,
    );
    expect(spread.cornerWeight, 1);
    expect(spread.diagonalWeight, 0);
  });

  test('单页后翻自由边遵循同机偏移并可返回原位', () {
    for (final size in [const Size(390, 844), const Size(600, 800)]) {
      for (final grab in [.13, .5, .87]) {
        final origin = Offset(size.width * .04, size.height * grab);
        for (final fraction in [.1, .4, .7]) {
          final target =
              origin +
              Offset(size.width * fraction, -size.width * fraction * .1);
          final pose = resolveBackwardCurlDrag(size, origin, target);
          final row = CurlGeometry(
            size: size,
            progress: pose.progress,
            grabY: pose.grabY,
            tilt: pose.tilt,
            cornerWeight: pose.cornerWeight,
            horizontalWeight: pose.horizontalWeight,
            diagonalWeight: pose.diagonalWeight,
          ).prepareRow(origin.dy);
          final point = row.project(pose.controlX).position;
          final wanted = Offset(target.dx - size.width * 4 / 390, target.dy);
          expect((point - wanted).distance, lessThan(.01));
        }
        expect(resolveBackwardCurlDrag(size, origin, origin).progress, 1);
        expect(
          resolveBackwardCurlDrag(
            size,
            origin,
            Offset(size.width * 1.1, origin.dy),
          ).progress,
          0,
        );
      }
    }
  });

  test('双页后翻自由边从左页连续进入，不改变书脊', () {
    const size = Size(390, 844), origin = Offset(-370, 700);
    for (final dx in [20.0, 100.0, 300.0, 600.0]) {
      final target = origin + Offset(dx, -dx * .05);
      final pose = resolveBackwardCurlDrag(size, origin, target, spread: true);
      final geometry = CurlGeometry(
        size: size,
        progress: pose.progress,
        grabY: pose.grabY,
        tilt: pose.tilt,
        cornerWeight: pose.cornerWeight,
        horizontalWeight: pose.horizontalWeight,
        diagonalWeight: pose.diagonalWeight,
      );
      expect(
        (geometry.project(pose.controlX, origin.dy).position - target).distance,
        lessThan(.01),
      );
      expect(geometry.project(0, origin.dy).position.dx, 0);
    }
  });

  test('收尾接管零位移保持原姿态，小位移及反向恢复连续', () {
    const size = Size(390, 844);
    final poses = [
      resolveForwardCurlDrag(
        size,
        const Offset(373, 700),
        const Offset(210, 670),
      ),
      resolveBackwardCurlDrag(
        size,
        const Offset(17, 700),
        const Offset(180, 670),
      ),
    ];
    for (var i = 0; i < poses.length; i++) {
      final start = poses[i];
      expect(continueCurlDrag(size, start, Offset.zero), same(start));
      for (final delta in [const Offset(-10, 2), const Offset(10, -2)]) {
        final moved = continueCurlDrag(size, start, delta);
        final returned = continueCurlDrag(size, moved, -delta);
        expect(returned.progress, closeTo(start.progress, 1e-6));
        expect(returned.tilt, closeTo(start.tilt, 1e-5));
        expect(moved.horizontalWeight, start.horizontalWeight);
        expect(moved.cornerWeight, start.cornerWeight);
      }
    }
  });

  test('向外页缘保持整页卷曲，向内完整页角保留局部性', () {
    const size = Size(390, 844);
    for (final grab in [.13, .87]) {
      final origin = Offset(373, size.height * grab);
      final sign = grab < .5 ? -1.0 : 1.0;
      for (final dx in [20.0, 40.0, 90.0, 160.0]) {
        final outward = resolveForwardCurlDrag(
          size,
          origin,
          origin + Offset(-dx, sign * dx * .4),
        );
        final inward = resolveForwardCurlDrag(
          size,
          origin,
          origin + Offset(-dx, -sign * dx * .4),
        );
        expect(outward.cornerWeight, 0);
        expect(inward.cornerWeight, 1);
        expect(outward.progress, inExclusiveRange(0, 1));
      }
    }
  });

  test('向外中间区域平滑建立局部性，上下及等比视口保持对应', () {
    for (final scale in [1.0, 2.0]) {
      final size = Size(390 * scale, 844 * scale);
      for (final grab in [.25, .75]) {
        final origin = Offset(373 * scale, size.height * grab);
        final sign = grab < .5 ? -1.0 : 1.0;
        for (final fraction in [.125, .25, .4]) {
          final dx = size.width * fraction;
          final pose = resolveForwardCurlDrag(
            size,
            origin,
            origin + Offset(-dx, sign * dx * .4),
          );
          expect(
            pose.cornerWeight,
            closeTo(fraction == .125 ? .1875 : .375, 1e-12),
          );
        }
      }
    }
  });

  test('向外局部性在建立末端及空间边界保持一阶连续', () {
    const size = Size(390, 844);
    double weight(double grab, double fraction) {
      final origin = Offset(373, size.height * grab);
      return resolveForwardCurlDrag(
        size,
        origin,
        origin + Offset(-size.width * fraction, size.width * fraction * .4),
      ).cornerWeight;
    }

    void smooth(double Function(double) value, double at) {
      const epsilon = 1e-5;
      final left = (value(at) - value(at - epsilon)) / epsilon;
      final right = (value(at + epsilon) - value(at)) / epsilon;
      expect(left, closeTo(right, .003));
    }

    smooth((fraction) => weight(.75, fraction), .25);
    smooth((grab) => weight(grab, .3), 2 / 3);
    smooth((grab) => weight(grab, .3), 5 / 6);
    smooth(
      (dy) => resolveForwardCurlDrag(
        size,
        const Offset(373, 633),
        Offset(333, 633 + dy),
      ).cornerWeight,
      0,
    );
  });

  test('双页偏移和 RTL 镜像还原为相同材料坐标', () {
    const point = Offset(350, 700);
    expect(curlPagePoint(const Size(390, 844), point), point);
    expect(
      curlPagePoint(const Size(780, 844), const Offset(740, 700), spread: true),
      point,
    );
    expect(
      curlPagePoint(const Size(390, 844), const Offset(40, 700), rtl: true),
      point,
    );
    expect(
      curlPagePoint(
        const Size(780, 844),
        const Offset(40, 700),
        spread: true,
        rtl: true,
      ),
      point,
    );
  });
  test('前翻几何控制点跟随二维拖动，原材料点偏差另行约束', () {
    for (final size in [const Size(390, 844), const Size(600, 800)]) {
      for (final grab in [0.13, 0.5, 0.87]) {
        final origin = Offset(size.width * 0.956, size.height * grab);
        for (final fraction in [0.05, 0.2, 0.45, 0.83]) {
          for (final vertical in [-0.25, 0.0, 0.25]) {
            final target =
                origin +
                Offset(
                  -size.width * fraction,
                  size.width * fraction * vertical,
                );
            final pose = resolveForwardCurlDrag(size, origin, target);
            expect(pose.controlX, inInclusiveRange(0, size.width));
            if (pose.cornerWeight == 1) expect(pose.controlX, origin.dx);
            final projected = CurlGeometry(
              size: size,
              progress: pose.progress,
              grabY: pose.grabY,
              tilt: pose.tilt,
              cornerWeight: pose.cornerWeight,
              horizontalWeight: pose.horizontalWeight,
              diagonalWeight: pose.diagonalWeight,
            ).project(pose.controlX, origin.dy);
            expect(
              (projected.position - target).distance,
              lessThan(0.01),
              reason: '$size grab=$grab target=$target',
            );
          }
        }
      }
    }
  });

  test('纯水平拖动在不同抓取高度使用相同圆柱截面', () {
    const size = Size(390, 844);
    for (final targetX in [292.0, 211.0, 129.0]) {
      final center = resolveForwardCurlDrag(
        size,
        const Offset(373, 422),
        Offset(targetX, 422),
      );
      for (final y in [112.0, 564.0, 732.0]) {
        final pose = resolveForwardCurlDrag(
          size,
          Offset(373, y),
          Offset(targetX, y),
        );
        expect(pose.cornerWeight, 0);
        expect(pose.progress, closeTo(center.progress, 0.000001));
        expect(pose.tilt, 0);
        final geometry = CurlGeometry(
          size: size,
          progress: pose.progress,
          grabY: pose.grabY,
          tilt: pose.tilt,
          cornerWeight: pose.cornerWeight,
          horizontalWeight: pose.horizontalWeight,
          diagonalWeight: pose.diagonalWeight,
        );
        // 整条材料行保持原高度，不能用倾斜补偿纵向透视而制造歪纸带。
        for (final row in [0.0, 211.0, 422.0, 844.0]) {
          final point = geometry.project(390, row).position;
          expect(point.dy, row);
          expect(
            point.dx,
            closeTo(geometry.project(390, 0).position.dx, 0.000001),
          );
        }
      }
    }
  });

  test('拖动方向跨过圆柱与页角过渡边界时纸角连续', () {
    const size = Size(390, 844);
    const origin = Offset(373, 732);
    for (final ratio in [0.0, 0.05, 0.2]) {
      final positions = <Offset>[];
      for (final delta in [-0.00001, 0.00001]) {
        final pose = resolveForwardCurlDrag(
          size,
          origin,
          Offset(129, 732 - 244 * (ratio + delta)),
        );
        positions.add(
          CurlGeometry(
            size: size,
            progress: pose.progress,
            grabY: pose.grabY,
            tilt: pose.tilt,
            cornerWeight: pose.cornerWeight,
            horizontalWeight: pose.horizontalWeight,
            diagonalWeight: pose.diagonalWeight,
          ).project(390, 844).position,
        );
      }
      expect((positions[0] - positions[1]).distance, lessThan(0.02));
    }
  });

  test('拖回同一位置恢复同一姿态，返回起点清除卷曲', () {
    const size = Size(390, 844);
    const origin = Offset(373, 732);
    const held = Offset(255, 645);
    final before = resolveForwardCurlDrag(size, origin, held);
    resolveForwardCurlDrag(size, origin, const Offset(48, 610));
    final after = resolveForwardCurlDrag(size, origin, held);
    expect(after.progress, before.progress);
    expect(after.tilt, before.tilt);
    expect(resolveForwardCurlDrag(size, origin, origin).progress, 0);
  });

  test('近乎竖直与越界拖动保持有限姿态，释放到端点不残留倾斜', () {
    const size = Size(390, 844);
    const origin = Offset(373, 732);
    for (final target in [
      Offset(372.9, -1000),
      Offset(-1000, 1000),
      Offset(1000, -1000),
    ]) {
      final pose = resolveForwardCurlDrag(size, origin, target);
      expect(pose.progress, inInclusiveRange(0, 1));
      expect(pose.tilt, inInclusiveRange(-2, 2));
      for (final end in [0.0, 1.0]) {
        final point = CurlGeometry(
          size: size,
          progress: end,
          grabY: pose.grabY,
          tilt: pose.tilt,
          cornerWeight: pose.cornerWeight,
          horizontalWeight: pose.horizontalWeight,
          diagonalWeight: pose.diagonalWeight,
        ).project(origin.dx, origin.dy);
        expect(
          point.position,
          Offset(end == 0 ? origin.dx : -origin.dx, origin.dy),
        );
        expect(point.depth, 0);
      }
    }
  });
  test('控制点在起卷和完成时归零，完成进度连续', () {
    const size = Size(390, 844);
    const origin = Offset(373, 732);
    for (final x in [373.0, -373.0]) {
      final end = resolveForwardCurlDrag(size, origin, Offset(x, 732));
      expect(end.controlX, 373);
      for (final delta in [.1, .01, .001]) {
        final pose = resolveForwardCurlDrag(
          size,
          origin,
          Offset(x + (x > 0 ? -delta : delta), 732),
        );
        if (x < 0) expect((pose.progress - end.progress).abs(), lessThan(.002));
        expect((pose.controlX - end.controlX).abs(), lessThan(.002));
      }
    }
  });

  test('水平停驻使用当前页内横坐标，三个起点复现同一姿态', () {
    const size = Size(390, 844);
    for (final targetX in [292.0, 211.0, 129.0]) {
      final reference = resolveForwardCurlDrag(
        size,
        const Offset(373, 732),
        Offset(targetX, 732),
      );
      for (final originX in [350.0, 373.0, 385.0]) {
        final pose = resolveForwardCurlDrag(
          size,
          Offset(originX, 732),
          Offset(targetX, 732),
        );
        expect(pose.progress, reference.progress);
        expect(pose.controlX, reference.controlX);
        expect(pose.tilt, 0);
        expect(pose.cornerWeight, 0);
      }
    }
  });

  test('水平参考逐步建立，中线斜拖保留原抓点', () {
    const size = Size(390, 844);
    const origin = Offset(373, 422);
    final beginning = resolveForwardCurlDrag(
      size,
      origin,
      const Offset(370, 422),
    );
    expect(beginning.horizontalWeight, greaterThan(0));
    expect(beginning.horizontalWeight, lessThan(.5));
    expect(
      resolveForwardCurlDrag(
        size,
        origin,
        const Offset(333, 422),
      ).horizontalWeight,
      1,
    );
    final diagonal = resolveForwardCurlDrag(
      size,
      origin,
      const Offset(211, 362),
    );
    expect(diagonal.cornerWeight, 0);
    expect(diagonal.horizontalWeight, 0);
    expect(diagonal.controlX, origin.dx);
  });
  test('斜拖参考只在已校准方向和中线区域内连续启用', () {
    const size = Size(390, 844), origin = Offset(373, 422);
    for (final (ratio, expected) in [(0.25, 0.0), (0.30, 0.5), (0.35, 1.0)]) {
      final pose = resolveForwardCurlDrag(
        size,
        origin,
        Offset(129, 422 - 244 * ratio),
      );
      expect(pose.diagonalWeight, closeTo(expected, 1e-12));
      expect(pose.horizontalWeight, 0);
    }
    final nearby = resolveForwardCurlDrag(
      size,
      const Offset(373, 380),
      const Offset(211, 320),
    );
    expect(nearby.diagonalWeight, greaterThan(0));
    expect(nearby.diagonalWeight, lessThan(1));
    for (final y in [300.0, 544.0]) {
      expect(
        resolveForwardCurlDrag(
          size,
          Offset(373, y),
          Offset(211, y - 60),
        ).diagonalWeight,
        0,
      );
    }
  });
  test('斜拖收拢不改变起卷、已校准水平配置和完整页角', () {
    for (final progress in [.0, .1, .2]) {
      expect(
        curlBendOpening(progress, .5, cornerWeight: 0, diagonalWeight: 1),
        curlBendOpening(progress, .5, cornerWeight: 0),
      );
    }
    expect(
      curlBendOpening(.4, .5, cornerWeight: 0, diagonalWeight: 1),
      lessThan(curlBendOpening(.4, .5, cornerWeight: 0)),
    );
    for (final corner in [0.0, .5, 1.0]) {
      expect(
        curlBendOpening(
          .4,
          .5,
          cornerWeight: corner,
          horizontalWeight: 1,
          diagonalWeight: 1,
        ),
        closeTo(
          curlBendOpening(.4, .5, cornerWeight: corner, horizontalWeight: 1),
          1e-12,
        ),
      );
    }
    expect(
      curlBendOpening(.4, .85, cornerWeight: 1, diagonalWeight: 1),
      closeTo(curlBendOpening(.4, .85, cornerWeight: 1), 1e-12),
    );
  });
  test('校准中线斜拖的控制点跟随已建立手势', () {
    for (final size in [const Size(390, 844), const Size(600, 800)]) {
      Offset scaled(double x, double y) =>
          Offset(size.width * x / 390, size.height * y / 844);
      for (final (y, x, targetY) in [
        (422.0, 211.0, 362.0),
        (422.0, 129.0, 350.0),
        (422.0, 211.0, 482.0),
        (380.0, 129.0, 308.0),
        (464.0, 129.0, 536.0),
      ]) {
        final origin = scaled(373, y);
        // 视口比例变化时保留实际拖动斜率，不能把各轴独立缩放当作同一方向。
        final target = Offset(
          size.width * x / 390,
          origin.dy + size.width * (targetY - y) / 390,
        );
        final pose = resolveForwardCurlDrag(size, origin, target);
        expect(pose.diagonalWeight, greaterThan(0));
        final geometry = CurlGeometry(
          size: size,
          progress: pose.progress,
          grabY: pose.grabY,
          tilt: pose.tilt,
          cornerWeight: pose.cornerWeight,
          horizontalWeight: pose.horizontalWeight,
          diagonalWeight: pose.diagonalWeight,
        );
        expect(
          (geometry.project(pose.controlX, origin.dy).position - target)
              .distance,
          lessThan(.01),
        );
      }
    }
  });
  test('早期陡拖输出有限且不启用后段张角收拢', () {
    const size = Size(390, 844);
    for (final grab in [.13, .5]) {
      final origin = Offset(size.width * .956, size.height * grab);
      final pose = resolveForwardCurlDrag(
        size,
        origin,
        origin + const Offset(-19.5, -7.8),
      );
      expect(pose.progress, lessThan(curlDiagonalStart));
      final retained = CurlGeometry(
        size: size,
        progress: pose.progress,
        grabY: pose.grabY,
        tilt: pose.tilt,
        cornerWeight: pose.cornerWeight,
        horizontalWeight: pose.horizontalWeight,
      );
      final current = CurlGeometry(
        size: size,
        progress: pose.progress,
        grabY: pose.grabY,
        tilt: pose.tilt,
        cornerWeight: pose.cornerWeight,
        horizontalWeight: pose.horizontalWeight,
        diagonalWeight: pose.diagonalWeight,
      );
      for (final y in [0.0, 422.0, 844.0]) {
        for (final x in [0.0, 195.0, 390.0]) {
          final vertex = current.project(x, y);
          expect(vertex.position.dx.isFinite, true);
          expect(vertex.position.dy.isFinite, true);
          expect(
            (vertex.position - retained.project(x, y).position).distance,
            lessThan(1e-12),
          );
        }
      }
    }
  });
}
