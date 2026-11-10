import 'dart:ui' as ui;

import 'package:fbooks/features/reader/presentation/page_curl/curl_painter.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingCanvas implements ui.Canvas {
  _CountingCanvas(this.canvas);
  final ui.Canvas canvas;
  var calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
  @override
  void save() => canvas.save();
  @override
  void restore() => canvas.restore();
  @override
  void saveLayer(ui.Rect? bounds, ui.Paint paint) =>
      canvas.saveLayer(bounds, paint);
  @override
  void translate(double dx, double dy) => canvas.translate(dx, dy);
  @override
  void scale(double sx, [double? sy]) => canvas.scale(sx, sy);
  @override
  ui.Rect getLocalClipBounds() => canvas.getLocalClipBounds();
  @override
  void drawImageRect(
    ui.Image image,
    ui.Rect source,
    ui.Rect target,
    ui.Paint paint,
  ) => canvas.drawImageRect(image, source, target, paint);
  @override
  void drawVertices(ui.Vertices vertices, ui.BlendMode mode, ui.Paint paint) {
    calls++;
    canvas.drawVertices(vertices, mode, paint);
  }

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) => canvas.drawRect(rect, paint);
  @override
  void drawPath(ui.Path path, ui.Paint paint) => canvas.drawPath(path, paint);
}

ui.Image _page(int index) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 512, 768),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(512, 768), [
        Color(0xff102030 + index * 0x203010),
        const Color(0xfffaf6ec),
      ]),
  );
  for (var y = 4; y < 764; y += 8) {
    canvas.drawRect(
      Rect.fromLTWH(4, y.toDouble(), 504, 2),
      Paint()..color = const Color(0xff132435),
    );
  }
  final picture = recorder.endRecording();
  try {
    return picture.toImageSync(512, 768);
  } finally {
    picture.dispose();
  }
}

Future<List<int>> _pixels(CurlPainter painter) async {
  const size = Size(300, 225), ratio = 2.625;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..scale(ratio)
    ..clipRect(Offset.zero & size, doAntiAlias: false);
  painter.paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (size.width * ratio).ceil(),
    (size.height * ratio).ceil(),
  );
  try {
    return (await image.toByteData())!.buffer.asUint8List().toList();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('深度交错的双页绘制批次有界，大网格复用缓冲区', () {
    final image = _page(0);
    int calls(
      bool opaque, {
      int columns = 96,
      int rows = 48,
      bool batch = true,
    }) {
      final recorder = ui.PictureRecorder();
      final canvas = _CountingCanvas(Canvas(recorder));
      canvas.canvas.clipRect(const Rect.fromLTWH(-3000, -3000, 6000, 6000));
      CurlPainter(
        images: List.filled(4, image),
        progress: .35,
        spread: true,
        opaquePages: opaque,
        batchOpaqueSpread: opaque && batch,
        grabY: .5,
        tilt: 1,
        columns: columns,
        rows: rows,
      ).paint(canvas, const Size(300, 225));
      recorder.endRecording().dispose();
      return canvas.calls;
    }

    try {
      expect(calls(false), greaterThan(100));
      expect(calls(true, batch: false), greaterThan(100));
      expect(calls(true), lessThanOrEqualTo(5));
      // 顶点数量超过 16 位索引容量时仍可绘制阴影。
      expect(calls(true, columns: 256, rows: 256), lessThanOrEqualTo(5));
    } finally {
      image.dispose();
    }
  });

  test('可见面遮罩保持原图采样、遮挡和 RTL，限制图层边缘量化差异', () async {
    final images = [for (var i = 0; i < 4; i++) _page(i)];
    try {
      for (final rtl in [false, true]) {
        for (final progress in [.005, .15, .35, .52, .75, .995]) {
          for (final tilt in [-1.0, .232, 1.0]) {
            CurlPainter painter(bool opaque) => CurlPainter(
              images: images,
              progress: progress,
              spread: true,
              opaquePages: opaque,
              batchOpaqueSpread: opaque,
              rtl: rtl,
              grabY: .5,
              tilt: tilt,
            );
            final before = await _pixels(painter(false));
            final after = await _pixels(painter(true));
            var total = 0, exceptions = 0, alphaDifferences = 0;
            for (var pixel = 0; pixel < before.length; pixel += 4) {
              var difference = 0;
              for (var channel = 0; channel < 3; channel++) {
                final delta = (before[pixel + channel] - after[pixel + channel])
                    .abs();
                total += delta;
                if (delta > difference) difference = delta;
              }
              if (difference > 3) exceptions++;
              if (before[pixel + 3] != after[pixel + 3]) alphaDifferences++;
            }
            final pixelCount = before.length / 4;
            // 与真机画面对照使用同一量化边界，alpha 必须完全一致。
            expect(total / (pixelCount * 3), lessThan(.15));
            expect(exceptions / pixelCount, lessThan(.003));
            expect(alphaDifferences, 0);
          }
        }
      }
    } finally {
      for (final image in images) {
        image.dispose();
      }
    }
  });
}
