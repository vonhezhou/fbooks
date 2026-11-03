part of 'curl_geometry.dart';

class _ConeDirection {
  double x = 0, y = 1, z = 0;
  double nx = 0, ny = 0, nz = 1;
  double angle = 0;
}

// 平面、圆锥和切平面按母线连接。材料极坐标的角度除以 sin(beta)，
// 因而度量始终是 dr²+r²dtheta²；所有过渡只混合曲面参数，不混合顶点。
class _DevelopableCurlSurface {
  _DevelopableCurlSurface(CurlGeometry g)
    : size = g.size,
      camera =
          g.size.width *
          curlCameraScaleForCorner(
            g.cornerWeight ?? curlCornerWeightForGrab(g.grabY),
            horizontalWeight: g.horizontalWeight,
          ),
      verticalWeight = g.verticalProjectionWeight,
      nativeWeight =
          (1 - (g.cornerWeight ?? curlCornerWeightForGrab(g.grabY))) *
          g.horizontalWeight {
    final t = g.progress, wave = math.sin(math.pi * t);
    final grab = g.grabY.clamp(0.0, 1.0);
    final corner = g.cornerWeight ?? curlCornerWeightForGrab(grab);
    final tilt = g.tilt ?? (grab - .5) * 1.6 * size.width / size.height;
    final weight = g.cornerLimit.abs().clamp(0.0, 1.0);
    final baseLower = tilt >= 0;
    final center = size.width * (1 - t);
    final minimum = size.width * .05;
    var inverseApex =
        3 * tilt / (size.width * (.001 + math.max(0.0, 2 - tilt.abs())));
    double smooth(double x) {
      final v = x.clamp(0.0, 1.0);
      return v * v * (3 - 2 * v);
    }

    inverseApex *= smooth(t / .05) * smooth((1 - t) / .05);

    var radius =
        size.width *
        curlRadiusScaleForGrab(
          grab,
          cornerWeight: corner,
          progress: t,
          horizontalWeight: g.horizontalWeight,
        ) *
        math.pow(wave, .6) *
        .82;
    var materialCenter = center;
    var bendLimit =
        math.pi -
        curlBendOpening(
          t,
          grab,
          cornerWeight: corner,
          horizontalWeight: g.horizontalWeight,
          diagonalWeight: g.diagonalWeight,
        );
    if (weight > 0) {
      const peak = .33;
      final phase = t <= peak ? t / peak : (1 - t) / (1 - peak);
      final normal =
          (.92 + (g.cornerLimit.sign * tilt - 1) * .2) * smooth(phase);
      double hermite(double x, double y, double vx, double vy, double u) =>
          (2 * u * u * u - 3 * u * u + 1) * x +
          (u * u * u - 2 * u * u + u) * vx +
          (-2 * u * u * u + 3 * u * u) * y +
          (u * u * u - u * u) * vy;
      final q =
          size.width *
          (t <= peak
              ? hermite(1, .14, -1.5 * peak, -.3 * peak, t / peak)
              : hermite(.14, 0, -.3 * (1 - peak), 0, (t - peak) / (1 - peak)));
      final capGrab = size.height * (g.cornerLimit > 0 ? 1 - grab : grab);
      final capInverse = normal <= 0
          ? 0.0
          : g.cornerLimit.sign / math.max(minimum, q / normal);
      inverseApex += (capInverse - inverseApex) * weight;
      materialCenter += (q + normal * capGrab - materialCenter) * weight;
      final capRadius =
          size.width *
          .07 *
          math.min(1.0, math.max(0, q) / (size.width * .14)) *
          smooth(t / .05);
      radius += (capRadius - radius) * weight;
      bendLimit += (math.pi - bendLimit) * weight;
    }
    lower = inverseApex == 0 ? baseLower : inverseApex > 0;
    final a = size.height * (lower ? 1 - grab : grab);
    // 倾斜卷曲逐渐靠近书脊时收拢弯曲带，保留尚未卷入的平面。
    // 圆柱极限不受影响；这是整张曲面的半径参数，不能按顶点压缩。
    final extent = inverseApex.abs() * size.height;
    final concentration = extent * extent / (1 + extent);
    final excess =
        radius * math.pi / (2 * math.max(materialCenter, size.width * 1e-9)) -
        .6;
    const rounding = .02;
    final positive = excess <= -rounding
        ? 0.0
        : excess >= rounding
        ? excess
        : (excess + rounding) * (excess + rounding) / (4 * rounding);
    radius /= 1 + concentration * positive;
    limit = math.pi - (math.pi - bendLimit) / (1 + concentration);
    _radius = math.max(radius, size.width * 1e-12);
    if (inverseApex.abs() * size.width < 1e-9) {
      _cylinder = true;
      _crease = materialCenter - math.pi * _radius / 2;
      final origin = _cylinderPoint(-_crease);
      _originX = origin.$1;
      _originZ = origin.$2;
      _backLight = .74 + .26 * math.cos(limit).abs();
      return;
    }
    apex = 1 / inverseApex.abs();
    final reach = math.sqrt(
      materialCenter * materialCenter + (apex + a) * (apex + a),
    );
    betaSine = math.min(.95, _radius / reach);
    betaCosine = math.sqrt(1 - betaSine * betaSine);
    join = math.atan2(materialCenter, apex + a) - math.pi * betaSine / 2;
    joinSine = math.sin(join);
    joinCosine = math.cos(join);
    final s = math.sin(limit),
        c = math.cos(limit),
        b = betaSine,
        k = betaCosine;
    _tx = b * s;
    _ty = b * b * c + k * k;
    _tz = b * k * (1 - c);
    _hx = c;
    _hy = -b * s;
    _hz = k * s;
    _tnx = -k * s;
    _tny = b * k * (1 - c);
    _tnz = b * b + k * k * c;
    _direction(0, _origin);
    _frameNorm = math.sqrt(1 - _origin.x * _origin.x);
    final ny = _tny * joinCosine - _tnx * joinSine;
    _backLight =
        .74 + .26 * ((-_origin.z * ny + _origin.y * _tnz) / _frameNorm).abs();
  }

  final Size size;
  final double camera, verticalWeight, nativeWeight;
  double? _nativeEdge;
  final _edgeProbe = CurlVertexBuffer();

  void prepareRow(double y) {
    if (nativeWeight == 0) return;
    projectInto(size.width, y, _edgeProbe);
    _nativeEdge = _edgeProbe.x;
  }

  late final bool lower;
  bool _cylinder = false;
  late final double limit, _radius, _backLight;
  late final double _crease, _originX, _originZ;
  late final double apex, betaSine, betaCosine, join, joinSine, joinCosine;
  late final double _tx, _ty, _tz, _hx, _hy, _hz, _tnx, _tny, _tnz, _frameNorm;
  final _origin = _ConeDirection(), _sample = _ConeDirection();

  (double, double) _cylinderPoint(double d) {
    if (d <= 0) return (d, 0);
    final angle = math.min(limit, d / _radius),
        tail = math.max(0.0, d - limit * _radius);
    return (
      _radius * math.sin(angle) + tail * math.cos(angle),
      _radius * (1 - math.cos(angle)) + tail * math.sin(angle),
    );
  }

  void _direction(double theta, _ConeDirection out) {
    if (theta <= join) {
      out
        ..x = math.sin(theta)
        ..y = math.cos(theta)
        ..z = 0
        ..nx = 0
        ..ny = 0
        ..nz = 1
        ..angle = 0;
      return;
    }
    final angular = theta - join, phi = angular / betaSine;
    double x, y, z, nx, ny, nz;
    if (phi <= limit) {
      final s = math.sin(phi), c = math.cos(phi), b = betaSine, k = betaCosine;
      x = b * s;
      y = b * b * c + k * k;
      z = b * k * (1 - c);
      nx = -k * s;
      ny = b * k * (1 - c);
      nz = b * b + k * k * c;
      out.angle = phi;
    } else {
      final delta = angular - betaSine * limit,
          c = math.cos(delta),
          s = math.sin(delta);
      x = _tx * c + _hx * s;
      y = _ty * c + _hy * s;
      z = _tz * c + _hz * s;
      nx = _tnx;
      ny = _tny;
      nz = _tnz;
      out.angle = limit;
    }
    out
      ..x = x * joinCosine + y * joinSine
      ..y = y * joinCosine - x * joinSine
      ..z = z
      ..nx = nx * joinCosine + ny * joinSine
      ..ny = ny * joinCosine - nx * joinSine
      ..nz = nz;
  }

  double rowRadius(double y) =>
      _cylinder ? _radius : (apex + (lower ? size.height - y : y)) * betaSine;

  void projectInto(double x, double y, CurlVertexBuffer out) {
    double px, py, z, nx, ny, nz, angle;
    if (_cylinder) {
      final d = x - _crease, p = _cylinderPoint(d);
      angle = (d / _radius).clamp(0.0, limit);
      px = p.$1 - _originX;
      py = y;
      z = p.$2 - _originZ;
      nx = -math.sin(angle);
      ny = 0;
      nz = math.cos(angle);
    } else {
      final cy = lower ? size.height - y : y,
          v = apex + cy,
          r = math.sqrt(x * x + v * v);
      _direction(math.atan2(x, v), _sample);
      final dx = _sample.x - _origin.x,
          dy = _sample.y - _origin.y,
          dz = _sample.z - _origin.z;
      final separation = (dx * dx + dy * dy + dz * dz) / 2;
      px = r * (dx + _origin.x * separation) / _frameNorm;
      final canonicalY = cy + x * x / (r + v) - r * separation;
      py = lower ? size.height - canonicalY : canonicalY;
      z = r * (dz * _origin.y - dy * _origin.z) / _frameNorm;
      nx =
          (_sample.nx -
              _origin.x *
                  (_sample.nx * _origin.x +
                      _sample.ny * _origin.y +
                      _sample.nz * _origin.z)) /
          _frameNorm;
      ny =
          (_sample.nx * _origin.x +
              _sample.ny * _origin.y +
              _sample.nz * _origin.z) *
          (lower ? -1 : 1);
      nz = (-_sample.ny * _origin.z + _sample.nz * _origin.y) / _frameNorm;
      angle = _sample.angle;
    }
    final perspective = 1 / (1 - z / camera);
    final vertical = curlVerticalProjectionScale(perspective, verticalWeight);
    final facing =
        nz -
        nx * px * perspective / camera -
        ny *
            (py - size.height / 2) *
            verticalWeight *
            perspective *
            perspective /
            (camera * vertical);
    final diffuse = (.74 + .26 * nz.abs()) / (facing < 0 ? _backLight : 1);
    final s = math.sin(angle), s2 = s * s, s4 = s2 * s2;
    var lighting = diffuse + .12 * s4 * s4 * s4;
    if (_nativeEdge case final edge?) {
      final sigma = math.max(3.0, rowRadius(y) * .15 - 5);
      final distance = (px * perspective - edge).abs() / sigma;
      final opacity = (.355 * (1 - edge / size.width - .268)).clamp(0.0, .25);
      final native = angle > math.pi / 2
          ? 1 - .035 * s4
          : lighting *
                (1 - opacity * math.exp(-distance * math.sqrt(distance)));
      lighting += (native - lighting) * nativeWeight;
    }
    out
      ..x = px * perspective
      ..y = (py - size.height / 2) * vertical + size.height / 2
      ..depth = z
      ..light = lighting.clamp(0.0, 1.0)
      ..facing = facing
      ..back = facing < 0;
    if (x == 0) {
      out
        ..x = 0
        ..y = y
        ..depth = 0;
    }
  }
}
