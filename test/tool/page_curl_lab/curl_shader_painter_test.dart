import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/curl_geometry.dart';
import '../../../tool/page_curl_lab/curl_drag.dart';
import '../../../tool/page_curl_lab/curl_painter.dart';
import '../../../tool/page_curl_lab/curl_shader_painter.dart';

Future<Image> _page(int page) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 32, 48),
    Paint()..color = Color(0xff305080 + page * 0x203010),
  );
  canvas.drawRect(
    const Rect.fromLTWH(2, 4, 12, 20),
    Paint()..color = const Color(0xfffaf6ec),
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(32, 48);
  } finally {
    picture.dispose();
  }
}

Future<List<int>> _pixels(
  CustomPainter painter, {
  double outputScale = 1,
  Size size = const Size(96, 128),
}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder)..scale(outputScale);
  painter.paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (size.width * outputScale).ceil(),
    (size.height * outputScale).ceil(),
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
  test('Shader 在局部、倾斜和混合曲面使用与 Mesh 完全一致的投影', () async {
    final image = await _page(0);
    final shader = (await FragmentProgram.fromAsset(curlShaderAsset))
        .fragmentShader();
    try {
      for (final (tilt, corner, limit) in [
        (-1.0, 1.0, -1.0),
        (1.0, 1.0, 1.0),
        (.4, .5, 0.0),
        (-.4, 0.0, 0.0),
        (0.0, 1.0, 0.0),
        (-.7, .5, .2),
      ]) {
        for (final rtl in [false, true]) {
          for (final spread in [false, true]) {
            final images = [image, image, image, image];
            final workspace = CurlMesh();
            final mesh = await _pixels(
              CurlPainter(
                images: images,
                progress: .33,
                tilt: tilt,
                cornerWeight: corner,
                cornerLimit: limit,
                spread: spread,
                rtl: rtl,
              ),
            );
            final fallback = await _pixels(
              CurlShaderPainter(
                shader: shader,
                mesh: workspace,
                images: images,
                progress: .33,
                tilt: tilt,
                cornerWeight: corner,
                cornerLimit: limit,
                spread: spread,
                rtl: rtl,
              ),
            );
            expect(fallback, orderedEquals(mesh));
          }
        }
      }
    } finally {
      image.dispose();
      shader.dispose();
    }
  });

  test('强斜拖实际朝向纸背的区域不误画为黑色正面', () async {
    final recorder = PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xff000000), BlendMode.src);
    final picture = recorder.endRecording();
    final black = await picture.toImage(32, 48);
    picture.dispose();
    final shader = (await FragmentProgram.fromAsset(curlShaderAsset))
        .fragmentShader();
    const size = Size(390, 844);
    try {
      for (final mirror in [false, true]) {
        double y(double value) => mirror ? size.height - value : value;
        // 保留强斜拖夹具；从实际投影的背面内部选点，避免依赖旧曲面的像素坐标。
        final pose = CurlDragPose(
          .26705482602119446,
          y(732) / size.height,
          (mirror ? -1 : 1) * 1.2412829925695754,
          1,
          373,
          0,
        );
        final g = CurlGeometry(
          size: size,
          progress: pose.progress,
          grabY: pose.grabY,
          tilt: pose.tilt,
          cornerWeight: pose.cornerWeight,
        );
        Offset? sample;
        var deepest = -double.infinity;
        for (var row = 1; row < 47; row++) {
          for (var col = 1; col < 95; col++) {
            final v = g.project(size.width * col / 96, size.height * row / 48);
            if (v.back &&
                v.depth > deepest &&
                v.position.dx > 4 &&
                v.position.dx < size.width - 4 &&
                v.position.dy > 4 &&
                v.position.dy < size.height - 4) {
              sample = v.position;
              deepest = v.depth;
            }
          }
        }
        expect(sample, isNotNull);
        for (final useShader in [false, true]) {
          final pixels = await _pixels(
            useShader
                ? CurlShaderPainter(
                    shader: shader,
                    images: [black, black],
                    progress: pose.progress,
                    grabY: pose.grabY,
                    tilt: pose.tilt,
                    cornerWeight: pose.cornerWeight,
                    horizontalWeight: pose.horizontalWeight,
                    diagonalWeight: pose.diagonalWeight,
                    spread: false,
                    paperColor: const Color(0xffffffff),
                  )
                : CurlPainter(
                    images: [black, black],
                    progress: pose.progress,
                    grabY: pose.grabY,
                    tilt: pose.tilt,
                    cornerWeight: pose.cornerWeight,
                    horizontalWeight: pose.horizontalWeight,
                    diagonalWeight: pose.diagonalWeight,
                    spread: false,
                    paperColor: const Color(0xffffffff),
                  ),
            size: size,
          );
          final offset = (sample!.dy.floor() * 390 + sample.dx.floor()) * 4;
          expect(
            pixels[offset],
            greaterThan(curlPaperBackAlpha * 0.8),
            reason: 'mirror=$mirror shader=$useShader',
          );
        }
      }
    } finally {
      shader.dispose();
      black.dispose();
    }
  });
  test('张角变化不把平直的白纸背整体染灰', () async {
    final recorder = PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xff000000), BlendMode.src);
    final picture = recorder.endRecording();
    final black = await picture.toImage(32, 48);
    picture.dispose();
    final shader = (await FragmentProgram.fromAsset(curlShaderAsset))
        .fragmentShader();
    try {
      for (final grab in [0.0, 0.5, 1.0]) {
        final point =
            CurlGeometry(size: const Size(96, 128), progress: 0.45, grabY: grab)
                .project(
                  90,
                  grab == 0
                      ? 5
                      : grab == 1
                      ? 123
                      : 64,
                )
                .position;
        final offset = (point.dy.floor() * 96 + point.dx.floor()) * 4;
        for (final useShader in [false, true]) {
          final pixels = await _pixels(
            useShader
                ? CurlShaderPainter(
                    shader: shader,
                    images: [black, black],
                    progress: 0.45,
                    spread: false,
                    grabY: grab,
                    paperColor: const Color(0xffffffff),
                  )
                : CurlPainter(
                    images: [black, black],
                    progress: 0.45,
                    spread: false,
                    grabY: grab,
                    paperColor: const Color(0xffffffff),
                  ),
          );
          // 黑色正面透过纸背涂层后的亮度由材质决定，保留原有 14 级插值余量。
          expect(
            pixels[offset],
            greaterThan(curlPaperBackAlpha - 14),
            reason: 'grab=$grab shader=$useShader',
          );
        }
      }
    } finally {
      shader.dispose();
      black.dispose();
    }
  });
  group('页角牵拉后的纸背内部不露出正面深色纹理', () {
    for (final grab in [112 / 844, 732 / 844]) {
      for (final progress in [0.08, 0.15, 0.27, 0.45, 0.7]) {
        for (final (tilt, cornerWeight, horizontalWeight, diagonalWeight)
            in <(double?, double?, double, double)>[
              if (progress != .08) ...[
                (null, null, 0, 0),
                (grab < 0.5 ? -0.4 : 0.4, null, 0, 0),
                (grab < 0.5 ? -1.0 : 1.0, null, 0, 0),
                // 方向权重同时改变半径与折线，过渡中的反解也必须完整覆盖。
                if (progress == 0.45) ...[
                  (0, 0, 0, 0),
                  (grab < 0.5 ? -.2 : .2, .5, 0, 0),
                  (0, 0, .5, 0),
                  (0, 0, 1, 0),
                  (grab < .5 ? -.05 : .05, .05, .5, 0),
                ],
              ],
              if (progress == .08 || progress == .27 || progress == .45) ...[
                (.3, 0, 0, 1),
                (-.3, 0, 0, .5),
              ],
              if (progress == .08) (.1, .5, 0, 0),
            ]) {
          test(
            'grab=$grab progress=$progress tilt=$tilt corner=$cornerWeight horizontal=$horizontalWeight diagonal=$diagonalWeight',
            () async {
              final recorder = PictureRecorder();
              Canvas(recorder)
                  .drawColor(const Color(0xff000000), BlendMode.src);
              final picture = recorder.endRecording();
              final black = await picture.toImage(32, 48);
              picture.dispose();
              final shader = (await FragmentProgram.fromAsset(curlShaderAsset))
                  .fragmentShader();
              const width = 390;
              const height = 844;
              try {
                final mesh = await _pixels(
                  CurlPainter(
                    rows: 192,
                    columns: 192,
                    images: [black, black],
                    progress: progress,
                    grabY: grab,
                    tilt: tilt,
                    cornerWeight: cornerWeight,
                    horizontalWeight: horizontalWeight,
                    diagonalWeight: diagonalWeight,
                    spread: false,
                    paperColor: const Color(0xffffffff),
                  ),
                  size: const Size(195, 422),
                  outputScale: 2,
                );
                final actual = await _pixels(
                  CurlShaderPainter(
                    shader: shader,
                    images: [black, black],
                    progress: progress,
                    grabY: grab,
                    tilt: tilt,
                    cornerWeight: cornerWeight,
                    horizontalWeight: horizontalWeight,
                    diagonalWeight: diagonalWeight,
                    spread: false,
                    paperColor: const Color(0xffffffff),
                    pixelRatio: 2,
                  ),
                  size: const Size(195, 422),
                  outputScale: 2,
                );
                var checked = 0;
                for (var y = 3; y < height - 3; y++) {
                  for (var x = 3; x < width - 3; x++) {
                    // 参考网格加密纵向采样，避免粗网格插值把材料边界外误判为纸背内部。
                    // 完整覆盖亮度随材质变化，仍以 14 级余量和三像素邻域排除半覆盖边带。
                    if (mesh[(y * width + x) * 4] < curlPaperBackAlpha - 14) {
                      continue;
                    }
                    var interior = true;
                    var minimum = 255;
                    for (var dy = -3; dy <= 3; dy++) {
                      for (var dx = -3; dx <= 3; dx++) {
                        final value = mesh[((y + dy) * width + x + dx) * 4];
                        if (value < minimum) minimum = value;
                        if (value < curlPaperBackAlpha - 14) {
                          interior = false;
                        }
                      }
                    }
                    if (!interior) continue;
                    checked++;
                    expect(
                      actual[(y * width + x) * 4],
                      greaterThan(100),
                      reason:
                          'grab=$grab progress=$progress tilt=$tilt at ($x,$y) meshMinimum=$minimum',
                    );
                  }
                }
                expect(checked, greaterThan(100));
              } finally {
                shader.dispose();
                black.dispose();
              }
            },
          );
        }
      }
    }
  });
  test('白纸纸背保持中性，复用网格切换纸色后恢复原像素', () async {
    final recorder = PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xffffffff), BlendMode.src);
    final picture = recorder.endRecording();
    final white = await picture.toImage(32, 48);
    picture.dispose();
    final program = await FragmentProgram.fromAsset(curlShaderAsset);
    final shader = program.fragmentShader();
    final mesh = CurlMesh();
    final point = const CurlGeometry(
      size: Size(96, 128),
      progress: 0.52,
    ).project(90, 64).position;
    final offset = (point.dy.floor() * 96 + point.dx.floor()) * 4;
    try {
      for (final useShader in [false, true]) {
        Future<List<int>> render(Color paper) => _pixels(
          useShader
              ? CurlShaderPainter(
                  shader: shader,
                  images: [white, white],
                  progress: 0.52,
                  spread: false,
                  paperColor: paper,
                )
              : CurlPainter(
                  mesh: mesh,
                  images: [white, white],
                  progress: 0.52,
                  spread: false,
                  paperColor: paper,
                ),
        );
        final sepia = await render(const Color(0xfffaf6ec));
        final neutral = await render(const Color(0xffffffff));
        expect(sepia[offset] - sepia[offset + 2], greaterThan(8));
        expect(
          (neutral[offset] - neutral[offset + 2]).abs(),
          lessThanOrEqualTo(1),
        );
        expect(await render(const Color(0xfffaf6ec)), orderedEquals(sepia));
      }
    } finally {
      shader.dispose();
      white.dispose();
    }
  });
  test('接近平放时阴影不突现，中段仍向底页投影', () async {
    final recorder = PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xffffffff), BlendMode.src);
    final picture = recorder.endRecording();
    final white = await picture.toImage(32, 48);
    picture.dispose();
    try {
      for (final progress in [0.000001, 0.52, 0.999999]) {
        final recording = PictureRecorder();
        final canvas = Canvas(recording)
          ..drawColor(const Color(0xffffffff), BlendMode.src)
          ..translate(24, 24);
        CurlPainter(
          images: [white, white],
          progress: progress,
          spread: false,
        ).paint(canvas, const Size(240, 320));
        final scene = recording.endRecording();
        final image = await scene.toImage(288, 368);
        try {
          final pixels = (await image.toByteData())!.buffer.asUint8List();
          var darkening = 0;
          final geometry = CurlGeometry(
            size: const Size(240, 320),
            progress: progress,
          );
          for (var y = 120; y < 200; y++) {
            var edge = double.negativeInfinity;
            for (var x = 0; x <= 96; x++) {
              final projected = geometry.project(x * 2.5, y.toDouble());
              if (projected.position.dx > edge) edge = projected.position.dx;
            }
            // 只观察纸面轮廓之外的白色底页，不把纸背颜色当成阴影。
            for (final distance in [2, 4, 6]) {
              final x = (edge + distance).ceil();
              final index = ((y + 24) * 288 + x + 24) * 4;
              for (var channel = 0; channel < 3; channel++) {
                final value = 255 - pixels[index + channel];
                if (value > darkening) darkening = value;
              }
            }
          }
          // 平放附近容许两级量化/抗锯齿误差；中段投影必须高于该噪声。
          expect(
            darkening,
            progress == 0.52 ? greaterThan(2) : lessThanOrEqualTo(2),
          );
        } finally {
          image.dispose();
          scene.dispose();
        }
      }
    } finally {
      white.dispose();
    }
  });

  test('网格预绘制不释放借用的纹理且不改变后续平面像素', () async {
    final images = <Image>[await _page(0), await _page(1)];
    try {
      final painter = CurlPainter(images: images, progress: 0, spread: false);
      final before = await _pixels(painter);
      await warmCurlMesh(
        images,
        size: const Size(96, 128),
        pixelRatio: 2,
        spread: false,
      );
      expect(await _pixels(painter), orderedEquals(before));
    } finally {
      for (final image in images) {
        image.dispose();
      }
    }
  });

  test('着色器的前后端点与网格保持相同页序和 RTL 方向', () async {
    final program = await FragmentProgram.fromAsset(curlShaderAsset);
    final shader = program.fragmentShader();
    final images = <Image>[];
    for (var i = 0; i < 4; i++) {
      images.add(await _page(i));
    }
    try {
      for (final spread in [false, true]) {
        for (final rtl in [false, true]) {
          for (final progress in [0.0, 1.0]) {
            final expected = await _pixels(
              CurlPainter(
                images: spread ? images : images.take(2).toList(),
                progress: progress,
                spread: spread,
                rtl: rtl,
              ),
            );
            final actual = await _pixels(
              CurlShaderPainter(
                shader: shader,
                images: spread ? images : images.take(2).toList(),
                progress: progress,
                spread: spread,
                rtl: rtl,
              ),
            );
            // 平面图片与三角形的纹理边缘有插值舍入差异；核对色块内部的页序和方向。
            for (final x in [8, 40, 56, 88]) {
              for (final y in [32, 100]) {
                final index = (y * 96 + x) * 4;
                expect(
                  actual.sublist(index, index + 4),
                  expected.sublist(index, index + 4),
                  reason:
                      'spread=$spread rtl=$rtl progress=$progress at ($x,$y)',
                );
              }
            }
          }
        }
      }
    } finally {
      shader.dispose();
      for (final image in images) {
        image.dispose();
      }
    }
  });
  test('着色器在不同页角和接近端点的卷曲中实际绘制曲面', () async {
    final program = await FragmentProgram.fromAsset(curlShaderAsset);
    final shader = program.fragmentShader();
    final images = <Image>[];
    for (var i = 0; i < 4; i++) {
      images.add(await _page(i));
    }
    try {
      final flat = await _pixels(
        CurlShaderPainter(
          shader: shader,
          images: images,
          progress: 0,
          spread: true,
        ),
      );
      // 检查未弯曲的正页色块，防止着色器全透明、仅底页仍可见也误判通过。
      final quarter = await _pixels(
        CurlShaderPainter(
          shader: shader,
          images: images,
          progress: 0.25,
          spread: true,
          grabY: 0.5,
        ),
      );
      final sample = (100 * 96 + 58) * 4;
      expect(quarter.sublist(sample, sample + 4), [80, 128, 144, 255]);
      for (final grab in [0.0, 0.5, 1.0]) {
        for (final progress in [0.000001, 0.25, 0.52, 0.75, 0.999999]) {
          final frame = await _pixels(
            CurlShaderPainter(
              shader: shader,
              images: images,
              progress: progress,
              spread: true,
              grabY: grab,
            ),
          );
          expect(frame.any((v) => v != 0), true);
          if (progress > 0.01 && progress < 0.99) {
            expect(frame, isNot(orderedEquals(flat)));
          }
        }
      }
    } finally {
      shader.dispose();
      for (final image in images) {
        image.dispose();
      }
    }
  });
  test('预热不释放页面资源，页缘半覆盖像素保留纸张颜色', () async {
    final program = await FragmentProgram.fromAsset(curlShaderAsset);
    final shader = program.fragmentShader();
    final images = <Image>[];
    for (var i = 0; i < 4; i++) {
      images.add(await _page(i));
    }
    final recorder = PictureRecorder();
    Canvas(recorder).drawColor(const Color(0x00000000), BlendMode.src);
    final picture = recorder.endRecording();
    final transparent = await picture.toImage(32, 48);
    picture.dispose();
    try {
      await warmCurlShader(shader, images.take(2).toList(), spread: false);
      double? firstNormalizedCoverage;
      for (final ratio in [1.0, 2.0, 3.0]) {
        final pixels = await _pixels(
          CurlShaderPainter(
            shader: shader,
            images: [images[0], transparent],
            progress: 0.52,
            grabY: .5,
            tilt: 0,
            cornerWeight: 0,
            spread: false,
            pixelRatio: ratio,
          ),
          outputScale: ratio,
        );
        var paperCoveragePixels = 0;
        for (var i = 0; i < pixels.length; i += 4) {
          if (pixels[i + 3] > 0 && pixels[i + 3] < 255 && pixels[i] > 0) {
            paperCoveragePixels++;
          }
        }
        // 黑色半透明投影不能冒充纸缘；过渡像素应随轮廓长度而非像素面积增长。
        expect(paperCoveragePixels, greaterThan(16 * ratio));
        final normalized = paperCoveragePixels / ratio;
        firstNormalizedCoverage ??= normalized;
        expect(
          normalized,
          closeTo(firstNormalizedCoverage, firstNormalizedCoverage * 0.5),
        );
      }
    } finally {
      shader.dispose();
      transparent.dispose();
      for (final image in images) {
        image.dispose();
      }
    }
  });
}
