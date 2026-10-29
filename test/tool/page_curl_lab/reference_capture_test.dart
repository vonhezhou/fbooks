import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/curl_painter.dart';
import '../../../tool/page_curl_lab/curl_shader_painter.dart';
import '../../../tool/page_curl_lab/reference_capture.dart';

void main() {
  testWidgets('参考采集连续取消保持源纹理，实际翻完才推进页序', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory.systemTemp.createTempSync(
      'fbooks-reference-test-',
    );
    final images = <ui.Image>[];
    final program = await tester.runAsync(() async {
      for (final color in [Colors.red, Colors.green, Colors.blue]) {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(color, BlendMode.src);
        final picture = recorder.endRecording();
        images.add(await picture.toImage(32, 48));
        picture.dispose();
      }
      return ui.FragmentProgram.fromAsset(curlShaderAsset);
    });
    try {
      const display = Key('reference-display');
      await tester.pumpWidget(
        RepaintBoundary(
          key: display,
          child: MaterialApp(
            home: CurlReferenceCapture(
              images: images,
              program: program!,
              output: output,
              sampleOnStart: false,
            ),
          ),
        ),
      );
      final paints = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is CurlPainter,
      );
      CurlPainter painter() =>
          tester.widget<CustomPaint>(paints).painter! as CurlPainter;
      Future<List<int>> displayedRgb() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(display),
        );
        return (await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final data = (await image.toByteData())!.buffer.asUint8List();
            final offset =
                ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
            return data.sublist(offset, offset + 3);
          } finally {
            image.dispose();
          }
        }))!;
      }

      expect(painter().images.first, same(images[0]));
      expect(await displayedRgb(), [244, 67, 54]);
      await tester.pump(const Duration(seconds: 21));
      expect(await displayedRgb(), [0, 0, 0]);
      await tester.tapAt(const Offset(195, 80));
      await tester.pump();
      expect(await displayedRgb(), [244, 67, 54]);
      expect(painter().images.first, same(images[0]));
      for (final target in [const Offset(211, 732), const Offset(211, 582)]) {
        final gesture = await tester.startGesture(const Offset(373, 732));
        await gesture.moveBy(const Offset(-25, 0));
        await gesture.moveTo(target);
        await tester.pump(const Duration(milliseconds: 300));
        expect(painter().progress, greaterThan(0));
        await tester.pump(const Duration(seconds: 21));
        expect(await displayedRgb(), isNot([0, 0, 0]));
        await gesture.moveTo(const Offset(373, 732));
        await tester.pump(const Duration(seconds: 1));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(painter().progress, 0);
        expect(painter().images.first, same(images[0]));
      }
      await tester.timedDragFrom(
        const Offset(373, 732),
        const Offset(-230, -30),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(painter().progress, 0);
      expect(painter().images.first, same(images[1]));

      // 前翻后可二维拖回上一页；取消必须恢复当前页，完整后翻才变更页序。
      final backOrigin = const Offset(17, 700);
      final back = await tester.startGesture(backOrigin);
      await back.moveBy(const Offset(30, 0));
      await back.moveTo(const Offset(300, 680));
      await tester.pump();
      expect(painter().images.first, same(images[0]));
      expect(painter().tilt, isNot(0));
      await back.cancel();
      await tester.pumpAndSettle();
      expect(painter().images.first, same(images[1]));
      await tester.timedDragFrom(
        backOrigin,
        const Offset(280, -20),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(painter().images.first, same(images[0]));
      // 首页不能后翻，末页不能继续前翻；三张纹理均可成为当前页。
      await tester.timedDragFrom(
        backOrigin,
        const Offset(200, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(painter().images.first, same(images[0]));
      for (final page in [1, 2, 2]) {
        await tester.timedDragFrom(
          const Offset(373, 700),
          const Offset(-280, 0),
          const Duration(seconds: 1),
        );
        await tester.pumpAndSettle();
        expect(painter().images.first, same(images[page]));
      }
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => output.delete(recursive: true));
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
