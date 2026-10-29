import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/curl_painter.dart';
import '../../../tool/page_curl_lab/curl_geometry.dart';
import '../../../tool/page_curl_lab/curl_shader_painter.dart';

import 'package:flutter/rendering.dart' show CustomPainter;

Future<Image> page(int n) async {
  final r = PictureRecorder();
  final c = Canvas(r);
  c.drawRect(
    const Rect.fromLTWH(0, 0, 64, 96),
    Paint()
      ..shader = Gradient.linear(Offset.zero, const Offset(64, 96), [
        Color(0xff102030 + n * 0x101010),
        const Color(0xfffaf6ec),
      ]),
  );
  for (var y = 5; y < 90; y += 8) {
    c.drawRect(
      Rect.fromLTWH(5, y.toDouble(), 48, 2),
      Paint()..color = const Color(0xff132435),
    );
  }
  final p = r.endRecording();
  try {
    return await p.toImage(64, 96);
  } finally {
    p.dispose();
  }
}

Future<List<int>> pixels(CustomPainter painter, {Rect? clip}) async {
  final r = PictureRecorder();
  final canvas = Canvas(r);
  if (clip != null) canvas.clipRect(clip);
  painter.paint(canvas, const Size(96, 192));
  final p = r.endRecording();
  final image = await p.toImage(96, 192);
  try {
    return (await image.toByteData())!.buffer.asUint8List().toList();
  } finally {
    image.dispose();
    p.dispose();
  }
}

class _UnculledMesh extends CurlMesh {
  @override
  void update(
    CurlGeometry geometry, {
    Color paperColor = const Color(0xfffaf6ec),
    Rect? clipBounds,
  }) {
    super.update(geometry, paperColor: paperColor);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('不透明单页合成保持全幅材质，允许消除旧批次边缘重复涂层', () async {
    final images = [for (var n = 0; n < 4; n++) await page(n)];
    final random = math.Random(17);
    var maximum = 0;
    try {
      for (var i = 0; i < 100; i++) {
        final progress = i < 8
            ? [.01, .15, .33, .53545, .67, .83, .95, .999][i]
            : random.nextDouble();
        final grab = i < 8 ? .5 : random.nextDouble(),
            tilt = i < 8 ? .232 : random.nextDouble() * 4 - 2;
        final corner = i < 8 ? 0.0 : random.nextDouble(),
            limit = i < 8 ? 0.0 : random.nextDouble() * 2 - 1;
        final horizontal = i < 8 ? 0.0 : random.nextDouble(),
            diagonal = random.nextDouble();
        final paper = i.isEven
            ? const Color(0xffffffff)
            : const Color(0xfffaf6ec);
        CurlPainter painter(bool opaque) => CurlPainter(
          images: images,
          progress: progress,
          spread: false,
          grabY: grab,
          tilt: tilt,
          cornerWeight: corner,
          cornerLimit: limit,
          horizontalWeight: horizontal,
          diagonalWeight: diagonal,
          paperColor: paper,
          rtl: i.isOdd,
          opaquePages: opaque,
        );
        final old = await pixels(painter(false)),
            current = await pixels(painter(true));
        var error = 0;
        for (var p = 0; p < old.length; p++) {
          error = math.max(error, (old[p] - current[p]).abs());
        }
        maximum = math.max(maximum, error);
        var exceptions = 0, totalError = 0;
        for (var k = 0; k < old.length; k += 4) {
          var difference = 0;
          for (var c = 0; c < 3; c++) {
            final delta = (old[k + c] - current[k + c]).abs();
            difference = math.max(difference, delta);
            totalError += delta;
          }
          if (difference > 3) exceptions++;
          expect(current[k + 3], old[k + 3]);
        }
        // 分离批次边缘原本可能重复叠加白涂层；合并后每个片元只着色一次。
        // 约束整幅差异及异常像素比例，不能以平均值掩盖大块材质/遮挡变化。
        expect(
          exceptions / (old.length / 4),
          lessThan(.002),
          reason: 'pose $i',
        );
        expect(
          totalError / (old.length / 4 * 3),
          lessThan(.1),
          reason: 'pose $i',
        );
        expect(error, lessThanOrEqualTo(64), reason: 'pose $i');
      }
      // ignore: avoid_print
      print('opaque composite max channel error: $maximum');
    } finally {
      for (final image in images) {
        image.dispose();
      }
    }
  });
  test('纯色不透明纸面保留真实透色和逐顶点明暗，仅有八位量化误差', () async {
    for (final color in [
      const Color(0xff000000),
      const Color(0xff808080),
      const Color(0xffffffff),
    ]) {
      final recorder = PictureRecorder();
      Canvas(recorder).drawColor(color, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(32, 48);
      picture.dispose();
      try {
        for (final p in [.05, .2, .4, .6, .8, .95]) {
          for (final paper in [
            const Color(0xffffffff),
            const Color(0xfffaf6ec),
          ]) {
            CurlPainter painter(bool opaque) => CurlPainter(
              images: [image, image],
              progress: p,
              spread: false,
              grabY: .5,
              tilt: 0,
              cornerWeight: 0,
              paperColor: paper,
              opaquePages: opaque,
            );
            final a = await pixels(painter(false)),
                b = await pixels(painter(true));
            for (var i = 0; i < a.length; i++) {
              expect((a[i] - b[i]).abs(), lessThanOrEqualTo(3));
            }
          }
        }
      } finally {
        image.dispose();
      }
    }
  });
  test('双页保持两个真实页面的贴图与遮挡契约', () async {
    final images = [for (var n = 0; n < 4; n++) await page(n)];
    try {
      for (final rtl in [false, true]) {
        final a = await pixels(
          CurlPainter(images: images, progress: .53545, spread: true, rtl: rtl),
        );
        final b = await pixels(
          CurlPainter(
            images: images,
            progress: .53545,
            spread: true,
            rtl: rtl,
            opaquePages: true,
          ),
        );
        expect(b, orderedEquals(a));
      }
    } finally {
      for (final image in images) {
        image.dispose();
      }
    }
  });
  test('Shader 回退继续使用相同的不透明单页合成路径', () async {
    final images = [await page(0), await page(1)];
    final shader = (await FragmentProgram.fromAsset(curlShaderAsset))
        .fragmentShader();
    try {
      final mesh = await pixels(
        CurlPainter(
          images: images,
          progress: .53545,
          spread: false,
          grabY: .5,
          tilt: .232,
          cornerWeight: 0,
          opaquePages: true,
        ),
      );
      final fallback = await pixels(
        CurlShaderPainter(
          shader: shader,
          images: images,
          progress: .53545,
          spread: false,
          grabY: .5,
          tilt: .232,
          cornerWeight: 0,
          opaquePages: true,
        ),
      );
      expect(fallback, orderedEquals(mesh));
    } finally {
      shader.dispose();
      for (final image in images) {
        image.dispose();
      }
    }
  });
  test('裁剪区外纸面剔除保留可见颜色、遮挡和完整阴影，空列表后可恢复', () async {
    final images = [await page(0), await page(1)];
    final mesh = CurlMesh();
    try {
      for (final p in [.535, .7, .9, .999, 0.0, 1.0, .25]) {
        for (final rtl in [false, true]) {
          for (final clip in [
            const Rect.fromLTWH(0, 0, 96, 192),
            const Rect.fromLTWH(20, 30, 60, 130),
            const Rect.fromLTWH(200, 0, 10, 192),
          ]) {
            CurlPainter painter(CurlMesh workspace) => CurlPainter(
              images: images,
              progress: p,
              spread: false,
              grabY: .5,
              tilt: .232,
              cornerWeight: 0,
              opaquePages: true,
              mesh: workspace,
              rtl: rtl,
            );
            final expected = await pixels(painter(_UnculledMesh()), clip: clip);
            final actual = await pixels(painter(mesh), clip: clip);
            expect(
              actual,
              orderedEquals(expected),
              reason: 'p=$p rtl=$rtl clip=$clip',
            );
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
