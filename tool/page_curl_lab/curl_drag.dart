import 'dart:math' as math;
import 'dart:ui';

import 'curl_geometry.dart';

// 只在新手势起手时判定；已起卷后的二维牵拉与收尾接管不受此限制。
// 保留坐标变换在等斜边界的浮点误差余量，不改变可见的角度阈值。
bool curlDragHasHorizontalIntent(Offset delta) =>
    delta.dx.abs() + .000001 >= delta.dy.abs();

class CurlDragPose {
  const CurlDragPose(
    this.progress,
    this.grabY,
    this.tilt,
    this.cornerWeight,
    this.controlX,
    this.horizontalWeight, [
    this.diagonalWeight = 0,
    this.cornerLimit = 0,
  ]);
  final double progress;
  final double grabY;
  final double tilt;
  final double cornerWeight;
  // 几何控制的材料横坐标；原始材料抓点的偏差另行报告。
  final double controlX;
  // 与有效页角局部性独立的、已建立近水平参考分量。
  final double horizontalWeight;
  // 中线附近、明显斜拖的参考分量；与水平配置的启用区间分开。
  final double diagonalWeight;
  final double cornerLimit;
}

Offset curlPagePoint(
  Size viewport,
  Offset point, {
  bool spread = false,
  bool rtl = false,
}) {
  final x = rtl ? viewport.width - point.dx : point.dx;
  return Offset(x - (spread ? viewport.width / 2 : 0), point.dy);
}

// 抓点不能比原材料位置更远离任一固定书脊端点。两圆盘的交集给出
// 屏幕平面上的保守可达范围；保持横向翻页意图，只限制纵向牵拉。
// 这约束控制目标，不裁剪或逐顶点压扁曲面，也不代替完整的物理求解。
Offset _constrainCurlTarget(
  Size size,
  double material,
  double grabY,
  Offset target,
) {
  final x = target.dx.clamp(-material, material);
  final y = size.height * grabY;
  final reachSquared = math.max(0.0, material * material - x * x);
  if (reachSquared == 0) return Offset(x, y);
  final top =
      size.height -
      math.sqrt(reachSquared + (size.height - y) * (size.height - y));
  final bottom = math.sqrt(reachSquared + y * y);
  return Offset(x, target.dy.clamp(top, bottom));
}

// 前后翻共用方向与局部性分类，后翻不重复执行前翻的进度反求。
({
  double grabY,
  double cornerWeight,
  double horizontalWeight,
  double diagonalWeight,
})
_curlDirectionProfile(
  Size size,
  Offset anchor,
  Offset position, {
  bool wholePage = false,
}) {
  final grab = anchor.dy / size.height;
  // Books 的纯水平拖动保留整页圆柱；斜拖才逐步启用局部页角。
  // 使用原始手势方向，避免透视补偿产生的微小 tilt 被当成斜拖。
  final direction =
      ((position.dy - anchor.dy).abs() /
              math.max(0.01, (position.dx - anchor.dx).abs()) /
              0.2)
          .clamp(0.0, 1.0);
  final rawCorner = curlCornerWeightForGrab(grab);
  final outward = (position.dy - anchor.dy) * (grab - .5) > 0;
  // 向外牵拉时，外缘保留整页轻卷；中间区域再逐步建立局部页角。
  // 向内牵拉仍使用原局部性，避免改变已验证的完整页角。
  final outer = ((rawCorner - .5) / .5).clamp(0.0, 1.0);
  final locality = ((position.dx - anchor.dx).abs() / size.width / .25).clamp(
    0.0,
    1.0,
  );
  final cornerWeight = wholePage
      ? 0.0
      : rawCorner *
            direction *
            direction *
            (3 - 2 * direction) *
            (outward
                ? locality *
                      locality *
                      (3 - 2 * locality) *
                      (1 - outer * outer * (3 - 2 * outer))
                : 1);
  // 参考截面仅用于接近水平的分量；起卷最初 5% 页宽内平滑建立，降低方向噪声。
  final ratio =
      (position.dy - anchor.dy).abs() /
      math.max(.01, (position.dx - anchor.dx).abs());
  // 方向和抓取区域均连续淡入，保留尚未校准的浅斜拖及局部页角。
  final diagonal = ((ratio - .25) / .1).clamp(0.0, 1.0);
  final central = ((.3 - cornerWeight) / .3).clamp(0.0, 1.0);
  final diagonalWeight =
      diagonal *
      diagonal *
      (3 - 2 * diagonal) *
      central *
      central *
      (3 - 2 * central);
  final near = (ratio / .05).clamp(0.0, 1.0);
  final established = ((position.dx - anchor.dx).abs() / size.width / .05)
      .clamp(0.0, 1.0);
  final horizontalWeight =
      (1 - near * near * (3 - 2 * near)) *
      established *
      established *
      (3 - 2 * established);
  return (
    grabY: grab,
    cornerWeight: cornerWeight,
    horizontalWeight: horizontalWeight,
    diagonalWeight: diagonalWeight,
  );
}

// 反求前翻时的几何控制点，横向决定进度，纵向决定折线倾斜。
// origin/position 均为去除双页偏移和 RTL 镜像后的单页坐标。
CurlDragPose resolveForwardCurlDrag(Size size, Offset origin, Offset position) {
  final pose = _resolveForwardCurlDrag(size, origin, position);
  final dx = (position.dx - origin.dx).abs();
  final dy = position.dy - origin.dy;
  double smooth(double value) {
    final t = value.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  // 向外牵拉较晚才转入另一页角；与向内路径分别校准，避免提前挪动正文。
  final outward = dy * (origin.dy / size.height - .5) > 0;
  final startRatio = outward ? .7 : .4, endRatio = outward ? 1.8 : 2.0;
  final weight =
      curlCornerWeightForGrab(origin.dy / size.height) *
      smooth(
        (dy.abs() / math.max(.01, dx) - startRatio) / (endRatio - startRatio),
      ) *
      smooth(dx / size.width / .05) *
      smooth((position.dx + origin.dx) / math.max(1, origin.dx) / .1);
  if (weight == 0 || pose.progress == 0 || pose.progress == 1) return pose;
  final side = -dy.sign;
  return CurlDragPose(
    pose.progress + (.33 - pose.progress) * weight,
    pose.grabY + ((side > 0 ? .87 : .13) - pose.grabY) * weight,
    pose.tilt + (side - pose.tilt) * weight,
    pose.cornerWeight,
    pose.controlX,
    pose.horizontalWeight,
    pose.diagonalWeight,
    side * weight,
  );
}

CurlDragPose _resolveForwardCurlDrag(
  Size size,
  Offset origin,
  Offset position,
) {
  var anchor = Offset(
    origin.dx.clamp(1.0, size.width),
    origin.dy.clamp(0.0, size.height),
  );
  position = _constrainCurlTarget(
    size,
    anchor.dx,
    anchor.dy / size.height,
    position,
  );
  final profile = _curlDirectionProfile(size, anchor, position);
  final grab = profile.grabY,
      cornerWeight = profile.cornerWeight,
      horizontalWeight = profile.horizontalWeight,
      diagonalWeight = profile.diagonalWeight;
  final originalX = anchor.dx;
  // 水平姿态按当前页内横坐标校准；三个起点的 Books 停驻画面一致。
  // 这是图像拟合的参考控制点，不代表原材料点或系统内部的真实抓点。
  final referenceX = size.width * 373 / 390;
  final fraction = ((referenceX - position.dx) / size.width).clamp(0.0, 2.0);
  final wanted = size.width / 390 * (1 + 25 * fraction * fraction);
  final maximum = size.width - referenceX,
      epsilon = math.min(size.width / 390, maximum / 2);
  final v = maximum - wanted;
  final positive = v <= -epsilon
      ? 0.0
      : v >= epsilon
      ? v
      : (v + epsilon) * (v + epsilon) / (4 * epsilon);
  final referenceControl =
      referenceX + (maximum - positive).clamp(0.0, maximum);
  final start = ((originalX - position.dx) / size.width / .05).clamp(0.0, 1.0);
  final finish = ((position.dx + originalX) / originalX).clamp(0.0, 1.0);
  final weight =
      (1 - cornerWeight) *
      horizontalWeight *
      start *
      start *
      (3 - 2 * start) *
      finish *
      finish *
      (3 - 2 * finish);
  anchor = Offset(
    originalX + (referenceControl - originalX) * weight,
    anchor.dy,
  );
  final targetX = position.dx.clamp(-originalX, originalX);
  if (targetX >= originalX) {
    return CurlDragPose(0, grab, 0, cornerWeight, originalX, horizontalWeight);
  }
  if (targetX <= -originalX) {
    return CurlDragPose(1, grab, 0, cornerWeight, originalX, horizontalWeight);
  }
  var low = 0.0;
  var high = 1.0;
  for (var i = 0; i < 24; i++) {
    final middle = (low + high) / 2;
    final point = CurlGeometry(
      size: size,
      progress: middle,
      tilt: 0,
      grabY: grab,
      cornerWeight: cornerWeight,
      horizontalWeight: horizontalWeight,
      diagonalWeight: diagonalWeight,
    ).project(anchor.dx, anchor.dy);
    if (point.position.dx > targetX) {
      low = middle;
    } else {
      high = middle;
    }
  }
  final progress = (low + high) / 2;
  final point = CurlGeometry(
    size: size,
    progress: progress,
    tilt: 0,
    grabY: grab,
    cornerWeight: cornerWeight,
    horizontalWeight: horizontalWeight,
    diagonalWeight: diagonalWeight,
  ).project(anchor.dx, anchor.dy);
  final scale =
      1 -
      point.depth /
          (size.width *
              curlCameraScaleForCorner(
                cornerWeight,
                horizontalWeight: horizontalWeight,
              ));
  final materialDelta = point.position.dx * scale - anchor.dx;
  final vertical =
      (position.dy - size.height / 2) /
          curlVerticalProjectionScale(1 / scale, cornerWeight) -
      (anchor.dy - size.height / 2);
  // 近乎竖直的轨迹超出当前曲面可表达范围；限制倾斜，避免除小量失控。
  // 这里限制的是乘 sin(pi * progress) 前的幅度；起卷阶段的常规斜拖需要超过 1.5。
  final tilt = materialDelta.abs() < 0.5
      ? 0.0
      : (vertical / materialDelta / math.sin(math.pi * progress)).clamp(
          -2.0,
          2.0,
        );
  return _resolveCurlControl(
    size,
    CurlDragPose(
      progress,
      grab,
      tilt,
      cornerWeight,
      anchor.dx,
      horizontalWeight,
      diagonalWeight,
    ),
    anchor.dx,
    position,
  );
}

// 单页后翻按同机参考牵拉可见自由边；双页仍牵拉已在左页的材料点。
// 两者都复用曲面与方向配置，避免线性倒放导致指针先走、纸张才出现。
CurlDragPose resolveBackwardCurlDrag(
  Size size,
  Offset origin,
  Offset position, {
  bool spread = false,
}) {
  final dx = position.dx - origin.dx;
  final direction = _curlDirectionProfile(
    size,
    Offset(size.width * 373 / 390, origin.dy),
    Offset(size.width * 373 / 390 - math.max(0, dx), position.dy),
    wholePage: !spread,
  );
  final profile = CurlDragPose(
    0,
    direction.grabY.clamp(0.0, 1.0),
    0,
    direction.cornerWeight,
    size.width,
    direction.horizontalWeight,
    direction.diagonalWeight,
  );
  final control = spread ? (-origin.dx).clamp(1.0, size.width) : size.width;
  if (dx <= 0) {
    return CurlDragPose(
      1,
      profile.grabY,
      0,
      profile.cornerWeight,
      control,
      profile.horizontalWeight,
      profile.diagonalWeight,
    );
  }
  // 起卷前 5% 页宽内建立进入画面的自由边，避免从隐藏页直接跳到可见姿态。
  final phase = (dx / size.width / .05).clamp(0.0, 1.0);
  final established = phase * phase * (3 - 2 * phase);
  final edge = position.dx - size.width * 4 / 390;
  return _resolveCurlControl(
    size,
    profile,
    control,
    Offset(
      spread ? position.dx : -size.width + (edge + size.width) * established,
      position.dy,
    ),
  );
}

// 接管时冻结当前纸张配置，只将新手势的相对位移施加给原控制点。
// 不重新套用初始抓取配置，否则倾斜、阴影和进度会在接管瞬间跳变。
CurlDragPose continueCurlDrag(Size size, CurlDragPose start, Offset delta) {
  if (delta == Offset.zero) return start;
  final point = _curlControlPoint(size, start, start.controlX);
  return _resolveCurlControl(size, start, start.controlX, point + delta);
}

Offset _curlControlPoint(Size size, CurlDragPose pose, double material) {
  final row = CurlGeometry(
    size: size,
    progress: pose.progress,
    grabY: pose.grabY,
    tilt: pose.tilt,
    cornerWeight: pose.cornerWeight,
    horizontalWeight: pose.horizontalWeight,
    diagonalWeight: pose.diagonalWeight,
    cornerLimit: pose.cornerLimit,
  ).prepareRow(size.height * pose.grabY);
  return row.project(material).position;
}

CurlDragPose _resolveCurlControl(
  Size size,
  CurlDragPose profile,
  double material,
  Offset wanted,
) {
  CurlDragPose at(double progress, double tilt) => CurlDragPose(
    progress,
    profile.grabY,
    tilt,
    profile.cornerWeight,
    material,
    profile.horizontalWeight,
    profile.diagonalWeight,
    profile.cornerLimit,
  );
  final left = -material;
  final right = material;
  wanted = _constrainCurlTarget(size, material, profile.grabY, wanted);
  final target = wanted.dx.clamp(left, right);
  if (target == left || target == right) {
    return at(target == left ? 1 : 0, 0);
  }
  // 先取得水平解作为起手种子；已建立手势则从原姿态迭代，避免切换分支。
  var low = 0.0, high = 1.0;
  for (var i = 0; i < 28; i++) {
    final middle = (low + high) / 2;
    if (_curlControlPoint(size, at(middle, 0), material).dx > target) {
      low = middle;
    } else {
      high = middle;
    }
  }
  final horizontal = (low + high) / 2;
  var best = at(profile.progress, profile.tilt);
  var bestError = (_curlControlPoint(size, best, material) - wanted).distance;
  final seeds = [
    (profile.progress, profile.tilt),
    (horizontal, 0.0),
    (horizontal, -.25),
    (horizontal, .25),
    (horizontal, -.5),
    (horizontal, .5),
    (horizontal, -1.0),
    (horizontal, 1.0),
    (horizontal, -2.0),
    (horizontal, 2.0),
  ];
  for (final seed in seeds) {
    var progress = seed.$1, tilt = seed.$2;
    var error = (_curlControlPoint(size, at(progress, tilt), material) - wanted)
        .distance;
    for (var i = 0; i < 24 && error > .00001; i++) {
      final point = _curlControlPoint(size, at(progress, tilt), material);
      const epsilon = .00001;
      final pa = (progress - epsilon).clamp(0.0, 1.0);
      final pb = (progress + epsilon).clamp(0.0, 1.0);
      final ta = (tilt - epsilon).clamp(-2.0, 2.0);
      final tb = (tilt + epsilon).clamp(-2.0, 2.0);
      final dp =
          (_curlControlPoint(size, at(pb, tilt), material) -
              _curlControlPoint(size, at(pa, tilt), material)) /
          (pb - pa);
      final dt =
          (_curlControlPoint(size, at(progress, tb), material) -
              _curlControlPoint(size, at(progress, ta), material)) /
          (tb - ta);
      final determinant = dp.dx * dt.dy - dt.dx * dp.dy;
      if (determinant.abs() < .00001) break;
      final delta = wanted - point;
      final stepP = (delta.dx * dt.dy - delta.dy * dt.dx) / determinant;
      final stepT = (dp.dx * delta.dy - dp.dy * delta.dx) / determinant;
      var accepted = false;
      for (final scale in [1.0, .5, .25, .125, .0625]) {
        final p = (progress + stepP * scale).clamp(.000000001, .999999999);
        final t = (tilt + stepT * scale).clamp(-2.0, 2.0);
        final next =
            (_curlControlPoint(size, at(p, t), material) - wanted).distance;
        if (next < error) {
          progress = p;
          tilt = t;
          error = next;
          accepted = true;
          break;
        }
      }
      if (!accepted) break;
    }
    if (error < bestError) {
      best = at(progress, tilt);
      bestError = error;
    }
    if (bestError < .00001) break;
  }
  return best;
}
