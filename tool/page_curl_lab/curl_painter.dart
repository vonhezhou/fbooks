import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'curl_geometry.dart';
import 'depth_sort.dart';

const curlMeshRows = 48;

/// 在可交互前提交近端点及翻至纸背的实际绘制，避免首个手势才建立绘制管线。
/// 使用真实视口与像素比例，使模糊阴影也走与屏幕相同的尺度；不持有或释放借用的页纹理。
Future<Duration> warmCurlMesh(
  List<ui.Image> images, {
  required Size size,
  required double pixelRatio,
  required bool spread,
  bool opaquePages = false,
  Color paperColor = const Color(0xfffaf6ec),
}) async {
  final watch = Stopwatch()..start();
  final mesh = CurlMesh();
  for (final horizontalWeight in [0.0, 1.0]) {
    for (final progress in [0.005, 0.52]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(pixelRatio);
      CurlPainter(
        images: images,
        progress: progress,
        spread: spread,
        mesh: mesh,
        opaquePages: opaquePages,
        paperColor: paperColor,
        horizontalWeight: horizontalWeight,
      ).paint(canvas, size);
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(
          (size.width * pixelRatio).ceil(),
          (size.height * pixelRatio).ceil(),
        );
        image.dispose();
      } finally {
        picture.dispose();
      }
    }
  }
  return watch.elapsed;
}

class CurlPainter extends CustomPainter {
  CurlPainter({
    required this.images,
    required this.progress,
    required this.spread,
    this.grabY = 0.8,
    this.tilt,
    this.cornerWeight,
    this.horizontalWeight = 0,
    this.diagonalWeight = 0,
    this.cornerLimit = 0,
    this.columns = 96,
    this.rows = curlMeshRows,
    this.rtl = false,
    this.onPaint,
    this.mesh,
    this.opaquePages = false,
    this.paperColor = const Color(0xfffaf6ec),
  });
  final List<ui.Image> images;
  final double progress;
  final bool spread;
  final double grabY;
  final double? tilt;
  final double? cornerWeight;
  final double horizontalWeight;
  final double diagonalWeight;
  final double cornerLimit;
  final int columns;
  final int rows;
  final bool rtl;
  final VoidCallback? onPaint;
  final CurlMesh? mesh;
  final Color paperColor;
  // 仅预先铺满纸底的不透明纹理可使用单次合成；透明来源保持原有 alpha 契约。
  final bool opaquePages;
  static final _identity = Float64List.fromList([
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ]);

  @override
  void paint(Canvas canvas, Size size) {
    onPaint?.call();
    final w = spread ? size.width / 2 : size.width;
    final pageSize = Size(w, size.height);
    canvas.save();
    // 只镜像场景坐标，贴图坐标另行抵消，保证 RTL 文字仍正向。
    if (rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    void flat(ui.Image image, double x) {
      canvas.save();
      canvas.translate(x, 0);
      if (rtl) {
        canvas.translate(w, 0);
        canvas.scale(-1, 1);
      }
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Offset.zero & pageSize,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    }

    if (spread) flat(images[0], 0);
    final origin = spread ? w : 0.0;
    flat(images[spread ? 3 : 1], origin);
    canvas.translate(origin, 0);
    final geometry = CurlGeometry(
      cornerLimit: cornerLimit,
      diagonalWeight: diagonalWeight,
      size: pageSize,
      progress: progress,
      grabY: grabY,
      tilt: tilt,
      cornerWeight: cornerWeight,
      horizontalWeight: horizontalWeight,
    );
    final workspace = mesh ?? CurlMesh(columns: columns, rows: rows);
    if (workspace.columns != columns || workspace.rows != rows) {
      throw ArgumentError('Mesh dimensions do not match painter');
    }
    workspace.update(
      geometry,
      paperColor: paperColor,
      clipBounds: opaquePages && !spread
          ? canvas.getLocalClipBounds().inflate(1)
          : null,
    );
    final vertices = workspace._vertices;
    final triangles = workspace._sorted;
    final boundary = Path();
    for (var i = 0; i <= columns; i++) {
      final p = vertices[i];
      if (i == 0) {
        boundary.moveTo(p.x, p.y);
      } else {
        boundary.lineTo(p.x, p.y);
      }
    }
    for (var i = 1; i <= rows; i++) {
      final p = vertices[i * (columns + 1) + columns];
      boundary.lineTo(p.x, p.y);
    }
    for (var i = columns - 1; i >= 0; i--) {
      final p = vertices[rows * (columns + 1) + i];
      boundary.lineTo(p.x, p.y);
    }
    boundary.close();
    if (progress > 0 && progress < 1) {
      final lift = vertices.fold(0.0, (z, v) => math.max(z, v.depth));
      // 纸面贴近底页时连续淡出，避免刚离开翻页端点就突现固定浓度的黑影。
      final height = (lift / 3).clamp(0.0, 1.0);
      final shadowOpacity = height * height * (3 - 2 * height);
      final localCorner = cornerWeight ?? curlCornerWeightForGrab(grabY);
      final nativeWeight = (1 - localCorner) * horizontalWeight;
      if (nativeWeight > 0) {
        final band = workspace._cylinderShadowGeometry(
          geometry,
          shadowOpacity * nativeWeight,
        );
        canvas.drawVertices(
          band,
          BlendMode.modulate,
          Paint()..color = Colors.white,
        );
        band.dispose();
      }
      if (nativeWeight < 1) {
        final shadow = workspace._shadowGeometry(
          pageSize,
          localCorner + (1 - localCorner) * cornerLimit.abs(),
          horizontalWeight,
        );
        if (shadow.vertices != null) {
          // 先在图层内合并不透明投影，重叠的曲面也只产生一份影子。
          canvas.saveLayer(
            null,
            Paint()
              ..color = Colors.black.withValues(
                alpha: 0.14 * shadowOpacity * (1 - nativeWeight),
              )
              ..imageFilter = ui.ImageFilter.blur(
                sigmaX: 1.5 + shadow.lift * 0.12,
                sigmaY: 1.5 + shadow.lift * 0.12,
              ),
          );
          canvas.drawVertices(
            shadow.vertices!,
            BlendMode.srcOver,
            Paint()..color = Colors.black,
          );
          canvas.restore();
          shadow.vertices!.dispose();
        }
        final contact = Path();
        var started = false;
        var contactDepth = 0.0;
        var contactPoints = 0;
        for (var row = 0; row <= rows; row++) {
          for (var col = 1; col <= columns; col++) {
            final v = vertices[row * (columns + 1) + col];
            if (!v.back) continue;
            var x = v.x, y = v.y, depth = v.depth;
            if (cornerLimit != 0) {
              final before = vertices[row * (columns + 1) + col - 1];
              final denominator = before.facing - v.facing;
              if (before.facing >= 0 && denominator > .000001) {
                final blend = (before.facing / denominator).clamp(0.0, 1.0);
                x = before.x + (v.x - before.x) * blend;
                y = before.y + (v.y - before.y) * blend;
                depth = before.depth + (v.depth - before.depth) * blend;
              }
            }
            contactDepth += depth;
            contactPoints++;
            x += depth * 0.08;
            if (!started) {
              contact.moveTo(x, y);
              started = true;
            } else {
              contact.lineTo(x, y);
            }
            break;
          }
        }
        final contactLift = contactPoints == 0
            ? 0.0
            : contactDepth / contactPoints;
        canvas.drawPath(
          contact,
          Paint()
            ..color = Colors.black.withValues(
              alpha: 0.04 * shadowOpacity * (1 - nativeWeight),
            )
            ..style = PaintingStyle.stroke
            // 接触暗部随离纸高度变宽，避免大页面出现固定比例的粗黑边。
            ..strokeWidth = 1.6 + contactLift * 0.025
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              math.max(0.5, contactLift * 0.06),
            ),
        );
      }
    }
    // 按深度排序，再合并连续同面三角形，避免每个三角形独立 draw call。
    // 深度排序可能产生数十个交错批次；同一页的着色器每帧只创建一次。
    final pagePaints = <ui.Image, Paint>{};
    final shaders = <ui.ImageShader>[];
    final coatingPaint = Paint()..color = Colors.white;
    final composite = opaquePages && !spread;
    var start = 0;
    try {
      while (start < triangles.length) {
        final back = triangles[start].back;
        var end = start + 1;
        while (end < triangles.length &&
            (composite || triangles[end].back == back)) {
          end++;
        }
        final image = images[spread ? (back ? 2 : 1) : 0];
        final positions = workspace._positions;
        final uv = workspace._uv;
        final colors = workspace._colors;
        var index = start * 3;
        for (var t = start; t < end; t++) {
          for (final v in triangles[t].indices) {
            final vertex = vertices[v];
            positions[index * 2] = vertex.x;
            positions[index * 2 + 1] = vertex.y;
            var u = workspace._normalizedUv[v * 2];
            if (back && spread) u = 1 - u;
            if (rtl) u = 1 - u;
            uv[index * 2] = u * image.width;
            uv[index * 2 + 1] =
                workspace._normalizedUv[v * 2 + 1] * image.height;
            colors[index] = composite
                ? workspace._opaquePalette[(triangles[t].back ? 256 : 0) +
                      (workspace._vertexColors[v] & 255)]
                : workspace._vertexColors[v];
            if (back && !spread) {
              workspace._paperColors[index] = workspace._vertexPaperColors[v];
            }
            index++;
          }
        }
        final mesh = ui.Vertices.raw(
          ui.VertexMode.triangles,
          Float32List.sublistView(positions, start * 6, end * 6),
          textureCoordinates: Float32List.sublistView(uv, start * 6, end * 6),
          colors: Int32List.sublistView(colors, start * 3, end * 3),
        );
        final pagePaint = pagePaints.putIfAbsent(image, () {
          final shader = ui.ImageShader(
            image,
            TileMode.clamp,
            TileMode.clamp,
            _identity,
            filterQuality: FilterQuality.medium,
          );
          shaders.add(shader);
          return Paint()..shader = shader;
        });
        // drawVertices 以图像为 src、顶点颜色为 dst；dstOver 将顶点涂层覆在图像上。
        canvas.drawVertices(
          mesh,
          composite ? BlendMode.dstOver : BlendMode.modulate,
          pagePaint,
        );
        if (back && !spread && !composite) {
          final paperColors = workspace._paperColors;
          final coating = ui.Vertices.raw(
            ui.VertexMode.triangles,
            Float32List.sublistView(positions, start * 6, end * 6),
            colors: Int32List.sublistView(paperColors, start * 3, end * 3),
          );
          canvas.drawVertices(coating, BlendMode.srcOver, coatingPaint);
          coating.dispose();
        }
        mesh.dispose();
        start = end;
      }
    } finally {
      for (final shader in shaders) {
        shader.dispose();
      }
    }
    if (progress > 0 && progress < 1) {
      canvas.drawPath(
        boundary,
        Paint()
          ..color = const Color(0xfffdfbf5).withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
    if (spread) {
      canvas.drawRect(
        Rect.fromLTWH(-w * 0.025, 0, w * 0.05, size.height),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(-w * 0.025, 0),
            Offset(w * 0.025, 0),
            [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.16),
              Colors.transparent,
            ],
            [0.0, 0.5, 1.0],
          ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CurlPainter old) =>
      old.opaquePages != opaquePages ||
      old.progress != progress ||
      old.grabY != grabY ||
      old.tilt != tilt ||
      old.cornerWeight != cornerWeight ||
      old.horizontalWeight != horizontalWeight ||
      old.diagonalWeight != diagonalWeight ||
      old.cornerLimit != cornerLimit ||
      old.spread != spread ||
      old.images != images ||
      old.columns != columns ||
      old.rows != rows ||
      old.rtl != rtl ||
      old.paperColor != paperColor;
}

/// 预分配拓扑及整页缓冲区；由阅读视图持有，跨动画帧复用。
class CurlMesh {
  CurlMesh({this.columns = 96, this.rows = curlMeshRows})
    : _vertices = List.generate(
        (columns + 1) * (rows + 1),
        (_) => CurlVertexBuffer(),
      ),
      _normalizedUv = Float64List((columns + 1) * (rows + 1) * 2),
      _vertexColors = Int32List((columns + 1) * (rows + 1)),
      _vertexPaperColors = Int32List((columns + 1) * (rows + 1)),
      _positions = Float32List(columns * rows * 12),
      _uv = Float32List(columns * rows * 12),
      _colors = Int32List(columns * rows * 6),
      _paperColors = Int32List(columns * rows * 6) {
    for (var row = 0; row <= rows; row++) {
      for (var col = 0; col <= columns; col++) {
        final v = row * (columns + 1) + col;
        _normalizedUv[v * 2] = col / columns;
        _normalizedUv[v * 2 + 1] = row / rows;
      }
    }
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final a = row * (columns + 1) + col;
        _triangles.add(_Triangle([a, a + 1, a + columns + 1]));
        _triangles.add(_Triangle([a + 1, a + columns + 2, a + columns + 1]));
      }
    }
    _sorted = List.of(_triangles);
  }

  final int columns;
  final int rows;
  final List<CurlVertexBuffer> _vertices;
  final _triangles = <_Triangle>[];
  late final List<_Triangle> _sorted;
  late final _depthSorter = CurlDepthSorter(_triangles.length);
  late final _depthWork = List<_Triangle?>.filled(_triangles.length, null);
  final Float64List _normalizedUv;
  final Int32List _vertexColors;
  final Int32List _vertexPaperColors;
  final Float32List _positions;
  final Float32List _uv;
  final Int32List _colors;
  final Int32List _paperColors;

  // 仅纸色变化时重建调色板，避免每个顶点重复计算颜色分量。
  final _paperPalette = Int32List(256);
  final _opaquePalette = Int32List(512);
  Color? _paperColor;
  late final _shadowProjected = Float32List(_vertices.length * 2);

  static const _bandColumns = 32;
  // 阴影独立采样，避免高密度曲面使 16 位条带索引回绕。
  late final _bandRows = math.min(rows, 1024);
  late final _bandPositions = Float32List(
    (_bandRows + 1) * (_bandColumns + 1) * 2,
  );
  late final _bandColors = Int32List((_bandRows + 1) * (_bandColumns + 1));
  late final _bandIndices = _makeBandIndices();
  static final _bandGaussian = List<double>.generate(_bandColumns + 1, (i) {
    final q = -4 + 8 * i / _bandColumns;
    return math.exp(-.5 * q * q);
  });
  final _foldVertex = CurlVertexBuffer();

  Uint16List _makeBandIndices() {
    final indices = Uint16List(_bandRows * _bandColumns * 6);
    var k = 0;
    for (var row = 0; row < _bandRows; row++) {
      for (var col = 0; col < _bandColumns; col++) {
        final a = row * (_bandColumns + 1) + col, b = a + _bandColumns + 1;
        indices[k++] = a;
        indices[k++] = a + 1;
        indices[k++] = b;
        indices[k++] = a + 1;
        indices[k++] = b + 1;
        indices[k++] = b;
      }
    }
    return indices;
  }

  // 以预分配的渐变条带跟随每行折线，避免把水平姿态的固定矩形阴影带入斜拖。
  ui.Vertices _cylinderShadowGeometry(CurlGeometry geometry, double opacity) {
    for (var row = 0; row <= _bandRows; row++) {
      final y = geometry.size.height * row / _bandRows,
          prepared = geometry.prepareRow(y);
      final sigma = 2 + .17 * prepared.radius, fold = prepared.foldX;
      prepared.projectFoldInto(_foldVertex);
      for (var col = 0; col <= _bandColumns; col++) {
        final i = row * (_bandColumns + 1) + col;
        _bandPositions[i * 2] =
            fold + sigma * (-.6 - 4 + 8 * col / _bandColumns);
        _bandPositions[i * 2 + 1] = _foldVertex.y;
        _bandColors[i] =
            (.2 * opacity * _bandGaussian[col] * 255).round() << 24;
      }
    }
    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      _bandPositions,
      colors: _bandColors,
      indices: _bandIndices,
    );
  }

  // 将抬起的三角形逐点落到底页平面，包含曲面内部形成的投影轮廓。
  ({ui.Vertices? vertices, double lift}) _shadowGeometry(
    Size size,
    double cornerWeight,
    double horizontalWeight,
  ) {
    var sum = 0.0;
    var count = 0;
    for (var i = 0; i < _vertices.length; i++) {
      final v = _vertices[i];
      final depth = math.max(0.0, v.depth);
      final scale =
          1 -
          depth /
              (size.width *
                  curlCameraScaleForCorner(
                    cornerWeight,
                    horizontalWeight: horizontalWeight,
                  ));
      _shadowProjected[i * 2] = v.x * scale + depth * 0.22;
      _shadowProjected[i * 2 + 1] =
          (v.y - size.height / 2) /
              curlVerticalProjectionScale(1 / scale, cornerWeight) +
          size.height / 2 +
          depth * 0.10;
      if (depth > 0.000001) {
        sum += depth;
        count++;
      }
    }
    var index = 0;
    for (final triangle in _triangles) {
      if (triangle.indices.every((i) => _vertices[i].depth <= 0.000001)) {
        continue;
      }
      for (final i in triangle.indices) {
        _positions[index++] = _shadowProjected[i * 2];
        _positions[index++] = _shadowProjected[i * 2 + 1];
      }
    }
    if (index == 0) return (vertices: null, lift: 0);
    return (
      vertices: ui.Vertices.raw(
        ui.VertexMode.triangles,
        Float32List.sublistView(_positions, 0, index),
      ),
      lift: count == 0 ? 0 : sum / count,
    );
  }

  void update(
    CurlGeometry geometry, {
    Color paperColor = const Color(0xfffaf6ec),
    Rect? clipBounds,
  }) {
    if (_paperColor != paperColor) {
      final rgb = paperColor.toARGB32();
      for (var shade = 0; shade < 256; shade++) {
        _paperPalette[shade] =
            curlPaperBackAlpha << 24 |
            (((rgb >> 16) & 255) * (shade / 255)).round() << 16 |
            (((rgb >> 8) & 255) * (shade / 255)).round() << 8 |
            ((rgb & 255) * (shade / 255)).round();
      }
      for (var shade = 0; shade < 256; shade++) {
        // srcOver: S + (1-a)*T = L*A*P + L*(1-A)*T。
        // 前面 A=0，背面 A=纸背涂层。深度排序不变，全部三角形共享一次绘制。
        _opaquePalette[shade] = (255 - shade) << 24;
        final alpha = 255 - ((255 - curlPaperBackAlpha) * shade / 255).round();
        int channel(int value) =>
            (value * curlPaperBackAlpha * shade / (255 * alpha)).round().clamp(
              0,
              255,
            );
        _opaquePalette[256 + shade] =
            alpha << 24 |
            channel((rgb >> 16) & 255) << 16 |
            channel((rgb >> 8) & 255) << 8 |
            channel(rgb & 255);
      }
      _paperColor = paperColor;
    }
    var vertex = 0;
    for (var row = 0; row <= rows; row++) {
      final prepared = geometry.prepareRow(geometry.size.height * row / rows);
      for (var col = 0; col <= columns; col++) {
        final projected = _vertices[vertex];
        prepared.projectInto(geometry.size.width * col / columns, projected);
        // 每个顶点只量化一次；纸背继续使用量化后的光照，保持原有颜色。
        final shade = (projected.light * 255).round();
        _vertexColors[vertex] = 0xff000000 | shade << 16 | shade << 8 | shade;
        _vertexPaperColors[vertex] = _paperPalette[shade];
        vertex++;
      }
    }
    _sorted.clear();
    for (final triangle in _triangles) {
      final a = _vertices[triangle.indices[0]];
      final b = _vertices[triangle.indices[1]];
      final c = _vertices[triangle.indices[2]];
      // 只剔除完全离开真实 Canvas 裁剪区的纸面三角形。
      // 顶点、阴影仍完整计算，翻出视口的纸面无需参与排序和提交。
      if (clipBounds != null &&
          ((a.x < clipBounds.left &&
                  b.x < clipBounds.left &&
                  c.x < clipBounds.left) ||
              (a.x > clipBounds.right &&
                  b.x > clipBounds.right &&
                  c.x > clipBounds.right) ||
              (a.y < clipBounds.top &&
                  b.y < clipBounds.top &&
                  c.y < clipBounds.top) ||
              (a.y > clipBounds.bottom &&
                  b.y > clipBounds.bottom &&
                  c.y > clipBounds.bottom))) {
        continue;
      }
      _sorted.add(triangle);
      triangle.depth = (a.depth + b.depth + c.depth) / 3;
      // 分行曲面经纵向牵拉后，截面转角不能代表实际面向；以投影绕序判断纸背。
      triangle.back = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) < 0;
    }
    // 可见集合从原始拓扑生成；优化路径对相同深度保留该顺序。
    if (clipBounds == null) {
      _sorted.sort((a, b) => a.depth.compareTo(b.depth));
    } else {
      final count = _sorted.length;
      for (var i = 0; i < count; i++) {
        final triangle = _sorted[i];
        _depthSorter.depths[i] = triangle.depth;
        _depthWork[i] = triangle;
      }
      final order = _depthSorter.sort(count);
      for (var i = 0; i < count; i++) {
        _sorted[i] = _depthWork[order[i]]!;
      }
    }
  }
}

class _Triangle {
  _Triangle(this.indices);
  final List<int> indices;
  double depth = 0;
  bool back = false;
}

double settleTarget(double progress, double velocity, double width) {
  // 快速抛掷优先；慢拖动按半页阈值决定完成或回弹。
  if (velocity.abs() > 500) return velocity < 0 ? 1 : 0;
  return progress >= 0.5 ? 1 : 0;
}

double dragProgress(double initial, double deltaX, double width) =>
    (initial - deltaX / math.max(1, width)).clamp(0.0, 1.0);
