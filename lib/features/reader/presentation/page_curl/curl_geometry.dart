import 'dart:math' as math;
import 'dart:ui';

part 'curl_surface.dart';

const curlCameraScale = 36.0;
double curlCameraScaleForCorner(
  double cornerWeight, {
  double horizontalWeight = 0,
}) =>
    curlCameraScale +
    (5 + (curlCameraScale - 5) * cornerWeight - curlCameraScale) *
        horizontalWeight;
const curlRadiusScale = 0.30;
const curlCenterRadiusScale = 0.42;
const curlRadiusTaper = -0.14;
const curlCreaseGain = 0.8;
const curlBendAmplitude = 1.16;
const curlCenterBendAmplitude = 1.2;
const curlDiagonalDrop = 0.3;
const curlDiagonalStart = 0.2;
const curlBendExponent = 0.2;
// 纸背涂层保留约两成源页透字；只改变文字反差，不把白纸整体染灰。
const curlPaperBackAlpha = 200;

double curlCornerWeightForGrab(double grabY) =>
    ((grabY - 0.5).abs() * 3).clamp(0.0, 1.0);

// 整页圆柱沿纵向保持正交投影；局部页角再平滑启用纵向透视。
double curlVerticalProjectionScale(double perspective, double cornerWeight) =>
    1 + (perspective - 1) * cornerWeight;

// 水平截面的参考参数只在已建立、接近水平的手势中启用。
// 页角权重描述空间局部性，不能代替手势方向，否则会改变中线斜拖。
double curlRadiusScaleForGrab(
  double grabY, {
  double? cornerWeight,
  required double progress,
  double horizontalWeight = 0,
}) {
  final corner = cornerWeight ?? curlCornerWeightForGrab(grabY);
  final legacy =
      curlCenterRadiusScale +
      (curlRadiusScale - curlCenterRadiusScale) * corner;
  if (horizontalWeight == 0 || corner == 1) return legacy;
  final raw = .17 - .16 * math.exp(-(progress - .158) / .075);
  const epsilon = .005;
  final positive = raw <= -epsilon
      ? 0.0
      : raw >= epsilon
      ? raw
      : (raw + epsilon) * (raw + epsilon) / (4 * epsilon);
  final center = .30 + positive;
  final reference = center + (curlRadiusScale - center) * corner;
  return legacy + (reference - legacy) * horizontalWeight;
}

double curlBendOpening(
  double progress,
  double grabY, {
  double? cornerWeight,
  double horizontalWeight = 0,
  double diagonalWeight = 0,
}) {
  final wave = math.sin(math.pi * progress),
      corner = cornerWeight ?? curlCornerWeightForGrab(grabY);
  final end = ((progress - .75) / .25).clamp(0.0, 1.0),
      flatten = 1 - end * end * (3 - 2 * end);
  final waveOpening = math.pow(wave, curlBendExponent);
  // 仅在已校准的中线斜拖后段逐渐收拢；不改变起卷和末段平放边界。
  final phase = ((progress - curlDiagonalStart) / .12).clamp(0.0, 1.0);
  final ramp = phase * phase * (3 - 2 * phase);
  final diagonalAmplitude =
      curlCenterBendAmplitude - curlDiagonalDrop * diagonalWeight * ramp;
  final legacy =
      (diagonalAmplitude + (curlBendAmplitude - diagonalAmplitude) * corner) *
      waveOpening *
      flatten;
  if (horizontalWeight == 0 || corner == 1) return legacy;
  final referencePhase = math.min(progress, 1.789 / (2 * 1.496));
  final center =
      1.233 - 1.789 * referencePhase + 1.496 * referencePhase * referencePhase;
  final reference =
      (center * (1 - corner) + curlBendAmplitude * waveOpening * corner) *
      flatten;
  return legacy + (reference - legacy) * horizontalWeight;
}

/// 为显式牵拉计算由轻卷平滑过渡到完整折线倾斜的增益。
///
/// [hasDirection] 为 `false` 或 [cornerWeight] 为 `1` 时保留
/// [curlCreaseGain]；其余纸面在 [progress] 的起卷阶段减弱远侧倾斜。
/// [cornerWeight] 使用控制器计算的 `0..1` 有效页角局部性。
double curlCreaseGainForProgress(
  double progress, {
  bool hasDirection = false,
  double cornerWeight = 0,
}) {
  if (!hasDirection) return curlCreaseGain;
  const startGain = .2, rampEnd = .16;
  final phase = (progress / rampEnd).clamp(0.0, 1.0);
  final gain =
      startGain +
      (curlCreaseGain - startGain) * phase * phase * (3 - 2 * phase);
  return curlCreaseGain + (gain - curlCreaseGain) * (1 - cornerWeight);
}

/// 后半程折线向未卷入的正文弯曲；起卷、完成及中线保持原截面。
double curlCreaseBow(double progress, double cornerWeight) {
  final advance = math.max(0.0, progress - 0.2);
  final ramp = advance < 0.1 ? advance * advance / 0.2 : advance - 0.05;
  final wave = math.sin(math.pi * progress);
  return 0.5 * wave * wave * ramp * cornerWeight;
}

class CurlVertex {
  const CurlVertex(this.position, this.depth, this.light, this.back);
  final Offset position;
  final double depth;
  final double light;
  final bool back;
}

/// 绘制工作区持有的顶点；原地更新标量，避免每帧分配顶点和 Offset。
class CurlVertexBuffer {
  double x = 0;
  double y = 0;
  double depth = 0;
  double light = 1;
  bool back = false;
  // 连续朝向分量用于插值纸背边界，避免阴影逐列跳动。
  double facing = 1;
}

/// 书脊固定的可展开卷曲曲面；按姿态选取等距圆柱或圆锥参数。
class CurlGeometry {
  const CurlGeometry({
    required this.size,
    required this.progress,
    this.grabY = 0.8,
    this.tilt,
    this.cornerWeight,
    this.horizontalWeight = 0,
    this.diagonalWeight = 0,
    this.cornerLimit = 0,
  });
  final Size size;
  final double progress;
  final double grabY;
  final double? tilt;
  final double? cornerWeight;
  final double horizontalWeight;
  final double diagonalWeight;
  // 强斜拖的参考极限；正值卷下角，负值卷上角，绝对值为混合权重。
  final double cornerLimit;

  bool get usesDevelopableSurface =>
      cornerLimit != 0 ||
      (tilt ?? (grabY - .5) * 1.6) != 0 ||
      (cornerWeight ?? curlCornerWeightForGrab(grabY)) != 0;

  double get verticalProjectionWeight {
    final corner = cornerWeight ?? curlCornerWeightForGrab(grabY);
    return corner + (1 - corner) * cornerLimit.abs().clamp(0.0, 1.0);
  }

  CurlRow prepareRow(double y) => CurlRow._(this, y);

  CurlVertex project(double x, double y) => prepareRow(y).project(x);
}

/// 同一行共享半径、折线和书脊积分值，避免在每个顶点重复计算。
class CurlRow {
  CurlRow._(CurlGeometry geometry, this._y)
    : _size = geometry.size,
      _t = geometry.progress.clamp(0.0, 1.0) {
    if (_t == 0 || _t == 1) return;
    if (geometry.usesDevelopableSurface) {
      _surface = _DevelopableCurlSurface(geometry)..prepareRow(_y);
      return;
    }
    final wave = math.sin(math.pi * _t);
    final grab = geometry.grabY.clamp(0.0, 1.0);
    final row = _y / _size.height;
    final offset = row - grab;
    final proximity = (1 - 2 * offset * offset).clamp(0.0, 1.0);
    final cornerWeight = geometry.cornerWeight ?? curlCornerWeightForGrab(grab);
    final cornerBias = (grab - 0.5).sign * cornerWeight;
    _cornerWeight = cornerWeight;
    _horizontalWeight = geometry.horizontalWeight;
    _pullScale = 1 - cornerBias * offset;
    // 中线截面沿纵向一致，页角才按离抓取行的距离改变张角与半径。
    _bendAngle =
        math.pi -
        curlBendOpening(
              _t,
              grab,
              cornerWeight: cornerWeight,
              horizontalWeight: geometry.horizontalWeight,
              diagonalWeight: geometry.diagonalWeight,
            ) *
            (1 - cornerWeight + cornerWeight * proximity * proximity);
    _sineLimit = math.sin(_bendAngle);
    _cosineLimit = math.cos(_bendAngle);
    _radius =
        _size.width *
        curlRadiusScaleForGrab(
          grab,
          cornerWeight: cornerWeight,
          progress: _t,
          horizontalWeight: geometry.horizontalWeight,
        ) *
        math.pow(wave, 0.6) *
        (0.82 + curlRadiusTaper * cornerWeight * (row - grab).abs());
    // 页角拖动时让远侧折线延后进入纸面，中线拖动仍保持圆柱卷曲。
    final corner = geometry.tilt == null
        ? (grab - 0.5) * 1.6
        : geometry.tilt! * _size.height / _size.width;
    // 仅弯曲抓取行到远侧页缘之间的折线。四次曲线在两端的一阶导数
    // 都为零，抓取行及自由页角不变，避免在抓取行制造新的折痕。
    final reach = grab >= 0.5 ? grab : 1 - grab;
    final far = grab >= 0.5 ? row : 1 - row;
    final q = (far / reach).clamp(0.0, 1.0);
    final bow = 16 * q * q * (1 - q) * (1 - q);
    _crease =
        _size.width * (1 - _t) -
        math.pi * _radius / 2 +
        corner *
            (grab - row) *
            _size.width *
            wave *
            curlCreaseGainForProgress(
              _t,
              hasDirection: geometry.tilt != null,
              cornerWeight: cornerWeight,
            ) +
        _size.width * curlCreaseBow(_t, cornerWeight) * bow;
    _originAlong = _along(-_crease);
    _originHeight = _height(-_crease);
    final ep = _along(_size.width - _crease) - _originAlong;
    final ez = _height(_size.width - _crease) - _originHeight;
    _freeEdgeX =
        ep /
        (1 -
            ez /
                (_size.width *
                    curlCameraScaleForCorner(
                      _cornerWeight,
                      horizontalWeight: _horizontalWeight,
                    )));
    _selfOpacity = (.355 * (1 - _freeEdgeX / _size.width - .268)).clamp(
      0.0,
      .25,
    );
    _tilt = corner * _size.width / _size.height * wave;
  }

  final Size _size;
  final double _y;
  final double _t;
  _DevelopableCurlSurface? _surface;
  final _foldProbe = CurlVertexBuffer();
  late final double _surfaceFold = _findSurfaceFold();

  double _findSurfaceFold() {
    final surface = _surface!;
    surface.projectInto(0, _y, _foldProbe);
    if (_foldProbe.back) return 0;
    surface.projectInto(_size.width, _y, _foldProbe);
    if (!_foldProbe.back) return _size.width;
    var low = 0.0, high = _size.width;
    for (var i = 0; i < 24; i++) {
      final x = (low + high) / 2;
      surface.projectInto(x, _y, _foldProbe);
      if (_foldProbe.back) {
        high = x;
      } else {
        low = x;
      }
    }
    return (low + high) / 2;
  }

  late final double _radius;
  late final double _crease;
  late final double _originAlong;
  late final double _originHeight;
  late final double _tilt;
  late final double _pullScale;
  late final double _cornerWeight;
  late final double _horizontalWeight;
  late final double _freeEdgeX, _selfOpacity;
  double get radius =>
      _t == 0 || _t == 1 ? 0 : _surface?.rowRadius(_y) ?? _radius;
  double get foldX {
    if (_t == 0 || _t == 1) return _t == 0 ? _size.width : -_size.width;
    if (_surface != null) return project(_surfaceFold).position.dx;
    final d =
            _size.width *
            curlCameraScaleForCorner(
              _cornerWeight,
              horizontalWeight: _horizontalWeight,
            ),
        h = d - _radius + _originHeight;
    return d *
        (-_originAlong * h +
            _radius *
                math.sqrt(
                  h * h + _originAlong * _originAlong - _radius * _radius,
                )) /
        (h * h - _radius * _radius);
  }

  void projectFoldInto(CurlVertexBuffer vertex) {
    if (_t == 0 || _t == 1) {
      projectInto(_size.width, vertex);
      return;
    }
    projectInto(foldMaterialX, vertex);
  }

  /// 折线投影极值对应的材料横坐标，用于后翻牵拉控制。
  double get foldMaterialX => _t == 0 || _t == 1
      ? _size.width
      : _surface != null
      ? _surfaceFold
      : _crease +
            _radius *
                (math.pi / 2 +
                    math.atan(
                      foldX /
                          (_size.width *
                              curlCameraScaleForCorner(
                                _cornerWeight,
                                horizontalWeight: _horizontalWeight,
                              )),
                    ));

  late final double _bendAngle;
  late final double _sineLimit;
  late final double _cosineLimit;
  late final double _backLight = 0.74 + 0.26 * _cosineLimit.abs();

  double _along(double d) => d <= 0
      ? d
      : d < _bendAngle * _radius
      ? _radius * math.sin(d / _radius)
      : _radius * _sineLimit + (d - _bendAngle * _radius) * _cosineLimit;

  double _height(double d) => d <= 0
      ? 0
      : d < _bendAngle * _radius
      ? _radius * (1 - math.cos(d / _radius))
      : _radius * (1 - _cosineLimit) + (d - _bendAngle * _radius) * _sineLimit;

  CurlVertex project(double x) {
    final vertex = CurlVertexBuffer();
    projectInto(x, vertex);
    return CurlVertex(
      Offset(vertex.x, vertex.y),
      vertex.depth,
      vertex.light,
      vertex.back,
    );
  }

  void projectInto(double x, CurlVertexBuffer vertex) {
    if (_t == 0 || _t == 1) {
      vertex
        ..x = _t == 0 ? x : -x
        ..y = _y
        ..depth = 0
        ..light = 1
        ..back = _t == 1
        ..facing = _t == 1 ? -1 : 1;
      return;
    }
    if (_surface case final surface?) {
      surface.projectInto(x, _y, vertex);
      return;
    }
    // 对书脊处积分值作差，保持整个装订边精确固定。
    final distance = x - _crease;
    final angle = (distance / _radius).clamp(0.0, _bendAngle);
    // 曲面坐标和光照使用相同的转角，每个顶点只计算一组正余弦。
    final sine = math.sin(angle);
    final cosine = math.cos(angle);
    final along = distance <= 0
        ? distance
        : distance < _bendAngle * _radius
        ? _radius * sine
        : _radius * sine + (distance - _bendAngle * _radius) * cosine;
    final height = distance <= 0
        ? 0.0
        : _radius * (1 - cosine) +
              math.max(0.0, distance - _bendAngle * _radius) * sine;
    final px = along - _originAlong;
    final z = height - _originHeight;
    // 回折位移沿倾斜折线的法向展开；平放区域位移为零，书脊也保持固定。
    // 抓取行保持完整牵拉，向自由页角衰减，避免整条自由边按同一剪切量被拉起。
    final py = _y + _tilt * _pullScale * (px - x);
    final perspective =
        1 /
        (1 -
            z /
                (_size.width *
                    curlCameraScaleForCorner(
                      _cornerWeight,
                      horizontalWeight: _horizontalWeight,
                    )));
    // 张角改变不应把整片平直纸背染灰；保留圆弧相对尾部的明暗变化。
    final diffuse =
        (0.74 + 0.26 * cosine.abs()) / (angle > math.pi / 2 ? _backLight : 1);
    final sineSquared = sine * sine;
    final sineFourth = sineSquared * sineSquared;
    final highlight = 0.12 * (sineFourth * sineFourth * sineFourth);
    var lighting = diffuse + highlight;
    final nativeWeight = (1 - _cornerWeight) * _horizontalWeight;
    if (nativeWeight > 0) {
      final sigma = math.max(3.0, _radius * .15 - 5);
      final distanceToEdge = (px * perspective - _freeEdgeX).abs() / sigma;
      final native = angle > math.pi / 2
          ? 1 - .035 * sineFourth
          : lighting *
                (1 -
                    _selfOpacity *
                        math.exp(-distanceToEdge * math.sqrt(distanceToEdge)));
      lighting += (native - lighting) * nativeWeight;
    }
    vertex
      ..x = px * perspective
      ..y =
          (py - _size.height / 2) *
              curlVerticalProjectionScale(perspective, _cornerWeight) +
          _size.height / 2
      ..depth = z
      ..light = lighting.clamp(0.0, 1.0)
      ..back = angle > math.pi / 2
      ..facing = cosine;
  }
}

Map<String, Object> summarizeFrames(List<FrameTiming> frames) {
  Map<String, double> distribution(List<double> samples) {
    if (samples.isEmpty) return {};
    samples.sort();
    double percentile(double p) => samples[(p * samples.length).ceil() - 1];
    return {
      'mean': samples.reduce((a, b) => a + b) / samples.length,
      'p95': percentile(0.95),
      'p99': percentile(0.99),
      'max': samples.last,
    };
  }

  return {
    'frames': frames.length,
    'build_ms': distribution([
      for (final f in frames) f.buildDuration.inMicroseconds / 1000,
    ]),
    'raster_ms': distribution([
      for (final f in frames) f.rasterDuration.inMicroseconds / 1000,
    ]),
    'total_span_ms': distribution([
      for (final f in frames) f.totalSpan.inMicroseconds / 1000,
    ]),
    // 两条流水线分别受帧预算约束；超预算比例不等同于实际丢帧率。
    for (final hz in [60, 120])
      'over_${hz}hz_pipeline_budget': frames.isEmpty
          ? 0.0
          : frames
                    .where(
                      (f) =>
                          f.buildDuration.inMicroseconds > 1000000 / hz ||
                          f.rasterDuration.inMicroseconds > 1000000 / hz,
                    )
                    .length /
                frames.length,
  };
}
