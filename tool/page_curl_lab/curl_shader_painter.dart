import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'curl_geometry.dart';
import 'curl_painter.dart';

const curlShaderAsset = 'tool/page_curl_lab/shaders/curl.frag';

/// 解析逆映射对照：只更新 uniform，由 GPU 逐像素求页面材料坐标。
class CurlShaderPainter extends CustomPainter {
  CurlShaderPainter({
    required this.shader,
    required this.images,
    required this.progress,
    required this.spread,
    this.grabY = 0.8,
    this.tilt,
    this.cornerWeight,
    this.horizontalWeight = 0,
    this.diagonalWeight = 0,
    this.cornerLimit = 0,
    this.rtl = false,
    this.onPaint,
    this.mesh,
    this.opaquePages = false,
    this.pixelRatio = 1,
    this.paperColor = const Color(0xfffaf6ec),
  });

  final ui.FragmentShader shader;
  final List<ui.Image> images;
  final double progress;
  final bool spread;
  final double grabY;
  final double? tilt;
  final double? cornerWeight;
  final double horizontalWeight;
  final double diagonalWeight;
  final double cornerLimit;
  final bool rtl;
  final VoidCallback? onPaint;
  final double pixelRatio;
  final Color paperColor;
  final CurlMesh? mesh;
  final bool opaquePages;

  @override
  void paint(Canvas canvas, Size size) {
    if (CurlGeometry(
      size: size,
      progress: progress,
      grabY: grabY,
      tilt: tilt,
      cornerWeight: cornerWeight,
      cornerLimit: cornerLimit,
    ).usesDevelopableSurface) {
      // 解析逆映射只覆盖水平参考圆柱；可展开斜曲面使用同一 Mesh。
      CurlPainter(
        images: images,
        progress: progress,
        spread: spread,
        grabY: grabY,
        tilt: tilt,
        cornerWeight: cornerWeight,
        horizontalWeight: horizontalWeight,
        diagonalWeight: diagonalWeight,
        cornerLimit: cornerLimit,
        rtl: rtl,
        onPaint: onPaint,
        mesh: mesh,
        opaquePages: opaquePages,
        paperColor: paperColor,
      ).paint(canvas, size);
      return;
    }
    onPaint?.call();
    final w = spread ? size.width / 2 : size.width;
    final t = progress.clamp(0.0, 1.0);
    canvas.save();
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
        Rect.fromLTWH(0, 0, w, size.height),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    }

    if (spread) flat(images[0], 0);
    final origin = spread ? w : 0.0;
    flat(images[spread ? 3 : 1], origin);
    if (t == 0) {
      flat(images[spread ? 1 : 0], origin);
    } else if (t == 1) {
      if (spread) flat(images[2], 0);
    } else {
      canvas.save();
      canvas.translate(origin, 0);
      final wave = math.sin(math.pi * t);
      final localCorner = cornerWeight ?? curlCornerWeightForGrab(grabY);
      final corner = tilt == null
          ? (grabY.clamp(0.0, 1.0) - 0.5) * 1.6
          : tilt! * size.height / w;
      shader
        ..setFloat(0, w)
        ..setFloat(1, size.height)
        ..setFloat(2, t)
        ..setFloat(3, grabY.clamp(0.0, 1.0))
        ..setFloat(4, wave)
        ..setFloat(
          5,
          w *
              curlRadiusScaleForGrab(
                grabY,
                cornerWeight: localCorner,
                progress: t,
                horizontalWeight: horizontalWeight,
              ) *
              math.pow(wave, 0.6),
        )
        ..setFloat(6, corner)
        ..setFloat(7, corner * w / size.height * wave)
        ..setFloat(8, spread ? 1 : 0)
        ..setFloat(9, rtl ? 1 : 0)
        ..setFloat(10, 1 / pixelRatio)
        ..setFloat(11, paperColor.r * 255)
        ..setFloat(12, paperColor.g * 255)
        ..setFloat(13, paperColor.b * 255)
        ..setFloat(
          14,
          curlCameraScaleForCorner(
            localCorner,
            horizontalWeight: horizontalWeight,
          ),
        )
        ..setFloat(
          15,
          curlCreaseGainForProgress(
            t,
            hasDirection: tilt != null,
            cornerWeight: localCorner,
          ),
        )
        ..setFloat(
          16,
          curlBendOpening(
            t,
            grabY,
            cornerWeight: localCorner,
            horizontalWeight: horizontalWeight,
            diagonalWeight: diagonalWeight,
          ),
        )
        ..setFloat(17, curlRadiusTaper)
        ..setFloat(18, localCorner)
        ..setFloat(19, curlCreaseBow(t, localCorner))
        ..setFloat(20, curlPaperBackAlpha / 255)
        ..setFloat(21, horizontalWeight)
        ..setImageSampler(0, images[spread ? 1 : 0])
        ..setImageSampler(1, images[spread ? 2 : 0]);
      canvas.drawRect(
        Rect.fromLTWH(spread ? -w : 0, 0, spread ? w * 2 : w, size.height),
        Paint()..shader = shader,
      );
      canvas.restore();
    }
    if (spread) {
      canvas.drawRect(
        Rect.fromLTWH(origin - w * 0.025, 0, w * 0.05, size.height),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(origin - w * 0.025, 0),
            Offset(origin + w * 0.025, 0),
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
  bool shouldRepaint(CurlShaderPainter old) =>
      old.opaquePages != opaquePages ||
      old.mesh != mesh ||
      old.shader != shader ||
      old.images != images ||
      old.progress != progress ||
      old.spread != spread ||
      old.grabY != grabY ||
      old.tilt != tilt ||
      old.cornerWeight != cornerWeight ||
      old.horizontalWeight != horizontalWeight ||
      old.diagonalWeight != diagonalWeight ||
      old.cornerLimit != cornerLimit ||
      old.rtl != rtl ||
      old.pixelRatio != pixelRatio ||
      old.paperColor != paperColor;
}

/// 在准备页面时实际提交一次着色器绘制，预热放在首个手势之前。
/// 小尺寸目标仅用于管线和图片采样器准备，不持有额外的页面缓存。
Future<Duration> warmCurlShader(
  ui.FragmentShader shader,
  List<ui.Image> images, {
  required bool spread,
  bool opaquePages = false,
  Color paperColor = const Color(0xfffaf6ec),
}) async {
  final watch = Stopwatch()..start();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  CurlShaderPainter(
    shader: shader,
    opaquePages: opaquePages,
    images: images,
    progress: 0.52,
    spread: spread,
    paperColor: paperColor,
  ).paint(canvas, const Size(64, 96));
  // 预热解析圆柱和可展开曲面的 Mesh 回退，避免默认页角只预热其中一条管线。
  CurlShaderPainter(
    shader: shader,
    opaquePages: opaquePages,
    images: images,
    progress: .52,
    spread: spread,
    grabY: .5,
    tilt: 0,
    cornerWeight: 0,
    paperColor: paperColor,
  ).paint(canvas, const Size(64, 96));
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(64, 96);
    image.dispose();
  } finally {
    picture.dispose();
  }
  return watch.elapsed;
}
