import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/curl_geometry.dart';
import '../../../tool/page_curl_lab/curl_painter.dart';

void main() {
  test('对角极限曲面保留纸面局部长度及固定书脊，收尾端点连续', () {
    const size = Size(390, 844);
    for (final side in [-1.0, 1.0]) {
      CurlGeometry geometry(double p) =>
          CurlGeometry(size: size, progress: p, tilt: side, cornerLimit: side);
      final g = geometry(.33);
      // 撤销相机投影，比较真实三维弦长。弦长允许略短于弧长，不能被剪切拉长。
      List<double> point(double x, double y) {
        final v = g.project(x, y);
        final scale = 1 - v.depth / (size.width * curlCameraScale);
        return [
          v.position.dx * scale,
          (v.position.dy - size.height / 2) * scale + size.height / 2,
          v.depth,
        ];
      }

      for (var row = 0; row <= 24; row++) {
        final y = size.height * row / 24;
        expect(g.project(0, y).position, Offset(0, y));
        for (var col = 0; col < 24; col++) {
          final x = size.width * col / 24;
          final a = point(x, y);
          for (final delta in [const Offset(.01, 0), const Offset(0, -.01)]) {
            final b = point(x + delta.dx, y + delta.dy);
            final squared = List.generate(
              3,
              (i) => (a[i] - b[i]) * (a[i] - b[i]),
            ).reduce((a, b) => a + b);
            expect(squared, closeTo(.0001, .0000001));
          }
        }
      }
      for (final p in [0.0, 1.0]) {
        final end = geometry(p).project(390, 732);
        final near = geometry(p == 0 ? .000001 : .999999).project(390, 732);
        expect((near.position - end.position).distance, lessThan(.01));
        expect(near.depth, lessThan(.01));
      }
    }
  });

  test('单页双页及 RTL 的中间帧可实际栅格化', () async {
    final sourceRecorder = PictureRecorder();
    final sourceCanvas = Canvas(sourceRecorder);
    sourceCanvas.drawRect(
      const Rect.fromLTWH(0, 0, 32, 48),
      Paint()..color = const Color(0xffcc9966),
    );
    final sourcePicture = sourceRecorder.endRecording();
    final image = await sourcePicture.toImage(32, 48);
    sourcePicture.dispose();
    try {
      for (final spread in [false, true]) {
        for (final rtl in [false, true]) {
          for (final progress in [0.0, 0.52, 1.0]) {
            final recorder = PictureRecorder();
            CurlPainter(
              images: [image, image, image, image],
              progress: progress,
              spread: spread,
              rtl: rtl,
            ).paint(Canvas(recorder), const Size(64, 96));
            final picture = recorder.endRecording();
            final frame = await picture.toImage(64, 96);
            picture.dispose();
            try {
              final pixels = await frame.toByteData();
              expect(pixels!.buffer.asUint8List().any((v) => v != 0), true);
            } finally {
              frame.dispose();
            }
          }
        }
      }
    } finally {
      image.dispose();
    }
  });
  test('复用工作区不会改写已记录但尚未栅格化的前一帧', () async {
    final sourceRecorder = PictureRecorder();
    Canvas(sourceRecorder).drawColor(const Color(0xffcc9966), BlendMode.src);
    final sourcePicture = sourceRecorder.endRecording();
    final image = await sourcePicture.toImage(32, 48);
    sourcePicture.dispose();
    final images = [image, image, image, image];
    final mesh = CurlMesh();
    Picture record(double progress, CurlMesh workspace) {
      final recorder = PictureRecorder();
      CurlPainter(
        images: images,
        progress: progress,
        spread: true,
        mesh: workspace,
      ).paint(Canvas(recorder), const Size(64, 96));
      return recorder.endRecording();
    }

    final first = record(0.25, mesh);
    final next = record(0.8, mesh);
    final expected = record(0.25, CurlMesh());
    try {
      final actualImage = await first.toImage(64, 96);
      final expectedImage = await expected.toImage(64, 96);
      try {
        final actualBytes = (await actualImage.toByteData())!.buffer
            .asUint8List();
        final expectedBytes = (await expectedImage.toByteData())!.buffer
            .asUint8List();
        expect(actualBytes, orderedEquals(expectedBytes));
      } finally {
        actualImage.dispose();
        expectedImage.dispose();
      }
    } finally {
      first.dispose();
      next.dispose();
      expected.dispose();
      image.dispose();
    }
  });
  const size = Size(600, 800);
  test('抓取侧回卷尾部保留张角，外角继续离开底页', () {
    for (final grab in [0.0, 1.0]) {
      final geometry = CurlGeometry(size: size, progress: 0.45, grabY: grab);
      final inner = geometry.project(size.width * 0.85, size.height * grab);
      final outer = geometry.project(size.width, size.height * grab);
      expect(inner.back && outer.back, true);
      expect(outer.depth, greaterThan(inner.depth + 10));
    }
  });
  test('中线拖动保留张角，纵向截面一致且尾部继续抬起', () {
    const geometry = CurlGeometry(size: size, progress: 0.45, grabY: 0.5);
    final inner = geometry.project(size.width * 0.85, size.height / 2);
    final outer = geometry.project(size.width, size.height / 2);
    expect(inner.back && outer.back, true);
    expect(outer.depth, greaterThan(inner.depth + 10));
    for (final y in [0.0, 200.0, 600.0, 800.0]) {
      final row = geometry.project(size.width, y);
      expect(row.depth, closeTo(outer.depth, 0.000001));
      expect(row.position.dx, closeTo(outer.position.dx, 0.000001));
    }
  });
  test('手机下页角回卷弧顶保留在页面内，外角沿弧顶向内回折', () {
    const phone = Size(390, 844);
    const geometry = CurlGeometry(
      size: phone,
      progress: 0.45,
      grabY: 732 / 844,
    );
    var fold = geometry.project(0, phone.height);
    for (var x = 0.5; x <= phone.width; x += 0.5) {
      final vertex = geometry.project(x, phone.height);
      if (vertex.position.dx > fold.position.dx) fold = vertex;
    }
    final tip = geometry.project(phone.width, phone.height);
    expect(fold.position.dy, lessThan(phone.height));
    expect(tip.position.dx, lessThan(fold.position.dx));
    expect(tip.position.dy, lessThan(fold.position.dy));
  });
  test('回折外角向纸面内侧抬起，上下页角方向相反', () {
    for (final progress in [0.15, 0.45, 0.7]) {
      final bottom = CurlGeometry(
        size: size,
        progress: progress,
        grabY: 1,
      ).project(size.width, size.height);
      final top = CurlGeometry(
        size: size,
        progress: progress,
        grabY: 0,
      ).project(size.width, 0);
      expect(bottom.position.dy, lessThan(size.height));
      expect(top.position.dy, greaterThan(0));
    }
  });
  test('回折页角在完成和取消端点连续恢复为平面', () {
    for (final grab in [0.0, 1.0]) {
      final y = size.height * grab;
      for (final end in [0.0, 1.0]) {
        final near = CurlGeometry(
          size: size,
          progress: end == 0 ? 1e-8 : 1 - 1e-8,
          grabY: grab,
        ).project(size.width, y);
        final target = CurlGeometry(
          size: size,
          progress: end,
          grabY: grab,
        ).project(size.width, y);
        expect((near.position - target.position).distance, lessThan(0.1));
        expect(near.depth, lessThan(0.1));
      }
    }
  });
  test('页角初始起卷集中在抓取侧，远侧页角尚未翻背', () {
    for (final grab in [0.0, 1.0]) {
      final geometry = CurlGeometry(size: size, progress: 0.15, grabY: grab);
      final farY = grab == 0 ? size.height : 0.0;
      final far = geometry.project(size.width, farY);
      expect(far.back, false);
      final near = geometry.project(size.width, grab * size.height);
      expect(far.depth, lessThan(near.depth * 0.1));
      expect(
        (far.position - Offset(size.width, farY)).distance,
        lessThan(
          (near.position - Offset(size.width, grab * size.height)).distance,
        ),
      );
      expect(near.depth, greaterThan(0));
      expect(near.position.dx, lessThan(size.width));
    }
  });
  test('折线前的材料保持平放，不提前产生纵向牵拉', () {
    for (final grab in [0.0, 0.5, 1.0]) {
      for (final y in [0.0, 200.0, 400.0, 600.0, 800.0]) {
        final vertex = CurlGeometry(
          size: size,
          progress: 0.15,
          grabY: grab,
        ).project(120, y);
        expect(vertex.position.dx, closeTo(120, 0.000001));
        expect(vertex.position.dy, closeTo(y, 0.000001));
        expect(vertex.depth, 0);
      }
    }
  });
  test('整个书脊在所有进度和页角位置保持固定', () {
    for (final progress in [0.01, 0.2, 0.5, 0.8, 0.99]) {
      for (final grab in [0.0, 0.5, 1.0]) {
        for (var y = 0.0; y <= 800; y += 40) {
          final vertex = CurlGeometry(
            size: size,
            progress: progress,
            grabY: grab,
          ).project(0, y);
          expect(vertex.position.dx, closeTo(0, 0.000001));
          expect(vertex.position.dy, closeTo(y, 0.000001));
          expect(vertex.depth, 0);
        }
      }
    }
  });
  test('上下页角拖动的形变互为镜像', () {
    for (final progress in [0.2, 0.5, 0.8]) {
      for (var x = 0.0; x <= 600; x += 100) {
        for (var y = 0.0; y <= 800; y += 100) {
          final top = CurlGeometry(
            size: size,
            progress: progress,
            grabY: 0,
          ).project(x, y);
          final bottom = CurlGeometry(
            size: size,
            progress: progress,
            grabY: 1,
          ).project(x, 800 - y);
          expect(top.position.dx, closeTo(bottom.position.dx, 0.000001));
          expect(top.position.dy, closeTo(800 - bottom.position.dy, 0.000001));
        }
      }
    }
  });
  test('端点完整覆盖正页与翻转后的背页，不残留弯曲', () {
    for (final point in [
      Offset.zero,
      const Offset(600, 800),
      const Offset(300, 400),
    ]) {
      final front = const CurlGeometry(
        size: size,
        progress: 0,
      ).project(point.dx, point.dy);
      final back = const CurlGeometry(
        size: size,
        progress: 1,
      ).project(point.dx, point.dy);
      expect(front.position, point);
      expect(back.position, Offset(-point.dx, point.dy));
      expect(front.back, false);
      expect(back.back, true);
      expect(front.depth, 0);
      expect(back.depth, 0);
    }
  });
  test('复用顶点到完成或回弹端点时清除上一帧的深度和光照', () {
    final vertex = CurlVertexBuffer();
    for (final target in [1.0, 0.0]) {
      const CurlGeometry(
        size: size,
        progress: 0.5,
      ).prepareRow(160).projectInto(500, vertex);
      expect(vertex.depth, greaterThan(0));
      CurlGeometry(
        size: size,
        progress: target,
      ).prepareRow(160).projectInto(500, vertex);
      expect(vertex.x, target == 0 ? 500 : -500);
      expect(vertex.y, 160);
      expect(vertex.depth, 0);
      expect(vertex.light, 1);
      expect(vertex.back, target == 1);
      expect(vertex.facing, target == 1 ? -1 : 1);
    }
  });
  test('拖拽边缘和接近端点时不产生 NaN 或无界坐标', () {
    for (final t in [0.000001, 0.1, 0.5, 0.9, 0.999999]) {
      for (final grab in [-1.0, 0.0, 0.5, 1.0, 2.0]) {
        for (var y = 0.0; y <= size.height; y += 80) {
          for (var x = 0.0; x <= size.width; x += 60) {
            final p = CurlGeometry(
              size: size,
              progress: t,
              grabY: grab,
            ).project(x, y);
            expect(p.position.dx.isFinite && p.position.dy.isFinite, true);
            expect(p.position.dx.abs(), lessThan(size.width * 3));
            // 曲面弧长由材料横坐标给定，离纸高度不能超过到书脊的材料距离。
            expect(p.depth, inInclusiveRange(0, x + 0.000001));
          }
        }
      }
    }
  });
  test('翻页与回弹按方向、速度及完成阈值判断', () {
    expect(settleTarget(0.2, -700, 600), 1);
    expect(settleTarget(0.8, 700, 600), 0);
    expect(settleTarget(0.49, 0, 600), 0);
    expect(settleTarget(0.51, 0, 600), 1);
    expect(dragProgress(0, -900, 600), 1);
    expect(dragProgress(1, 900, 600), 0);
  });
  test('指标区分两条流水线预算与端到端跨度', () {
    final timing = FrameTiming(
      buildStart: 0,
      buildFinish: 5000,
      rasterStart: 6000,
      rasterFinish: 16000,
      rasterFinishWallTime: 16000,
      vsyncStart: 0,
    );
    final metrics = summarizeFrames([timing]);
    expect(metrics['frames'], 1);
    expect(metrics['over_60hz_pipeline_budget'], 0);
    expect(metrics['over_120hz_pipeline_budget'], 1);
    expect((metrics['raster_ms']! as Map)['p95'], 10);
    expect((metrics['total_span_ms']! as Map)['max'], 16);
    expect(summarizeFrames([])['frames'], 0);
  });
  test('折线投影在平放端点返回自由边', () {
    for (final progress in [0.0, 1.0]) {
      for (final y in [0.0, 422.0, 844.0]) {
        final geometry = CurlGeometry(
          size: const Size(390, 844),
          progress: progress,
          horizontalWeight: 1,
        );
        final vertex = CurlVertexBuffer();
        geometry.prepareRow(y).projectFoldInto(vertex);
        expect(Offset(vertex.x, vertex.y), geometry.project(390, y).position);
        expect(vertex.depth, 0);
      }
    }
  });
  test('高纵向密度的水平投影完整覆盖底部', () async {
    final sourceRecorder = PictureRecorder();
    Canvas(sourceRecorder).drawPaint(Paint()..color = const Color(0xffffffff));
    final sourcePicture = sourceRecorder.endRecording();
    final image = await sourcePicture.toImage(32, 48);
    sourcePicture.dispose();
    try {
      const size = Size(390, 844);
      const progress = .35;
      final recorder = PictureRecorder();
      CurlPainter(
        images: [image, image],
        progress: progress,
        spread: false,
        grabY: .5,
        tilt: 0,
        cornerWeight: 0,
        horizontalWeight: 1,
        columns: 1,
        rows: 2000,
        paperColor: const Color(0xffffffff),
      ).paint(Canvas(recorder), size);
      final picture = recorder.endRecording(),
          frame = await picture.toImage(390, 844);
      picture.dispose();
      try {
        final bytes = (await frame.toByteData())!.buffer.asUint8List();
        final x =
            CurlGeometry(
              size: size,
              progress: progress,
              grabY: .5,
              tilt: 0,
              cornerWeight: 0,
              horizontalWeight: 1,
            ).prepareRow(422).foldX.round() +
            10;
        final middle = bytes[(422 * 390 + x) * 4],
            bottom = bytes[(842 * 390 + x) * 4];
        expect(middle, lessThan(250));
        expect((bottom - middle).abs(), lessThanOrEqualTo(1));
      } finally {
        frame.dispose();
      }
    } finally {
      image.dispose();
    }
  });
  test('早期倾斜只修正显式方向并保留完整页角', () {
    for (final progress in [0.0, .04, .08, .16, .5, 1.0]) {
      expect(curlCreaseGainForProgress(progress), curlCreaseGain);
      expect(
        curlCreaseGainForProgress(
          progress,
          hasDirection: true,
          cornerWeight: 1,
        ),
        curlCreaseGain,
      );
    }
    expect(
      curlCreaseGainForProgress(0, hasDirection: true),
      closeTo(.2, 1e-12),
    );
    expect(curlCreaseGainForProgress(.16, hasDirection: true), curlCreaseGain);
    final center = curlCreaseGainForProgress(.04, hasDirection: true);
    final partial = curlCreaseGainForProgress(
      .04,
      hasDirection: true,
      cornerWeight: .5,
    );
    expect(partial, greaterThan(center));
    expect(partial, lessThan(curlCreaseGain));
  });
  test('早期倾斜在建立和恢复处连续且一阶平滑', () {
    double gain(double progress) =>
        curlCreaseGainForProgress(progress, hasDirection: true);
    const epsilon = 1e-6;
    for (final edge in [0.0, .16]) {
      final left = (gain(edge) - gain(edge - epsilon)) / epsilon;
      final right = (gain(edge + epsilon) - gain(edge)) / epsilon;
      expect((left - right).abs(), lessThan(.001));
    }
  });
}
