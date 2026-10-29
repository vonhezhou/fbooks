import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/main.dart';
import '../../../tool/page_curl_lab/page_sources.dart';
import '../../../tool/page_curl_lab/curl_painter.dart';
import '../../../tool/page_curl_lab/curl_geometry.dart';
import '../../../tool/page_curl_lab/curl_drag.dart';
import '../../../tool/page_curl_lab/curl_shader_painter.dart';
import '../../../tool/page_curl_lab/renderer_selection.dart';

Future<void> waitForPage(WidgetTester tester, int page) async {
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (find.textContaining('· page $page ·').evaluate().isNotEmpty &&
        find.byKey(const Key('curl-surface')).evaluate().isNotEmpty) {
      // 页码在回翻动画前就更新；先让加载续体启动动画，再等待动画完成。
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      return;
    }
  }
  fail('Page $page did not become ready');
}

void main() {
  testWidgets('直接陡拖不翻页，下一次浅斜拖仍可起卷和取消', (tester) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: CurlLab()));
    await waitForPage(tester, 1);
    await tester.tap(find.text('Double page'));
    await waitForPage(tester, 1);
    CurlPainter paint() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<CurlPainter>()
        .single;
    final original = paint().images.first;
    final rect = tester.getRect(find.byKey(const Key('curl-surface')));
    final origin = rect.topLeft + Offset(rect.width * .956, rect.height * .87);
    final micro = await tester.startGesture(origin);
    await micro.moveBy(const Offset(-1, -1));
    await micro.up();
    await tester.pumpAndSettle();
    expect(paint().progress, 0);
    final steep = await tester.startGesture(origin);
    // 原生步进起初可能因像素取整暂时等斜，不能用这一步提前接受整条陡拖。
    await steep.moveBy(const Offset(-1, -1));
    await tester.pump();
    expect(paint().progress, 0);
    await steep.moveBy(Offset(-rect.width * .04, -rect.width * .08));
    await tester.pump();
    expect(paint().progress, 0);
    await steep.moveBy(Offset(-rect.width * .4, 0));
    await tester.pump();
    expect(paint().progress, 0);
    await steep.up();
    await waitForPage(tester, 1);
    final shallow = await tester.startGesture(origin);
    await shallow.moveBy(Offset(-rect.width * .15, -rect.width * .04));
    await tester.pump();
    expect(paint().progress, inExclusiveRange(0, 1));
    await shallow.moveTo(origin);
    await tester.pump(const Duration(milliseconds: 300));
    await shallow.up();
    await waitForPage(tester, 1);
    expect(paint().images.first, same(original));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('页角强斜拖把极限曲面传到画笔，拖回可取消', (tester) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: CurlLab()));
    await waitForPage(tester, 1);
    await tester.tap(find.text('Double page'));
    await waitForPage(tester, 1);
    CurlPainter paint() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<CurlPainter>()
        .single;
    final original = paint().images.first;
    final rect = tester.getRect(find.byKey(const Key('curl-surface')));
    final origin = rect.topLeft + Offset(rect.width * .956, rect.height * .87);
    final gesture = await tester.startGesture(origin);
    await gesture.moveBy(Offset(-rect.width * .1, -rect.width * .04));
    await gesture.moveTo(origin + Offset(-rect.width * .2, -rect.height * .6));
    await tester.pump();
    expect(paint().cornerLimit, 1);
    expect(paint().progress, .33);
    await gesture.moveTo(origin);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await waitForPage(tester, 1);
    expect(paint().progress, 0);
    expect(paint().images.first, same(original));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('按钮前翻也可被反向手势接管，取消后仍停留原页', (tester) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: CurlLab()));
    await waitForPage(tester, 1);
    await tester.tap(find.text('Double page'));
    await waitForPage(tester, 1);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    CurlPainter paint() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<CurlPainter>()
        .single;
    expect(paint().progress, inExclusiveRange(0, 1));
    final rect = tester.getRect(find.byKey(const Key('curl-surface')));
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveBy(Offset(rect.width * .08, 0));
    await tester.pump();
    await gesture.moveBy(Offset(rect.width * .8, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await waitForPage(tester, 1);
    expect(paint().progress, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final rtl in [false, true]) {
    testWidgets('前翻收尾可反向接管，旧动画不提交页序 rtl=$rtl', (tester) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: CurlLab()));
      await waitForPage(tester, 1);
      await tester.tap(find.text('Double page'));
      await waitForPage(tester, 1);
      if (rtl) {
        await tester.tap(find.text('LTR'));
        await tester.pump();
      }
      CurlPainter paint() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<CurlPainter>()
          .single;
      final original = paint().images.first;
      final rect = tester.getRect(find.byKey(const Key('curl-surface')));
      final sign = rtl ? -1.0 : 1.0;
      final from =
          rect.topLeft + Offset(rect.width * (rtl ? .1 : .9), rect.height * .7);
      final first = await tester.startGesture(from);
      await first.moveBy(Offset(-sign * rect.width * .08, 0));
      await first.moveBy(Offset(-sign * rect.width * .5, -20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await first.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final before = paint();
      expect(before.progress, inExclusiveRange(0, 1));
      final second = await tester.startGesture(rect.center);
      await second.moveBy(Offset(sign * rect.width * .08, 0));
      await tester.pump();
      final control = resolveForwardCurlDrag(
        rect.size,
        Offset(rect.width * .9, rect.height * .7),
        Offset(rect.width * .32, rect.height * .7 - 20),
      ).controlX;
      Offset projected(CurlPainter p) => CurlGeometry(
        size: rect.size,
        progress: p.progress,
        grabY: p.grabY,
        tilt: p.tilt,
        cornerWeight: p.cornerWeight,
        horizontalWeight: p.horizontalWeight,
        diagonalWeight: p.diagonalWeight,
      ).project(control, rect.height * before.grabY).position;
      // 手势识别已包含首次位移；纸张应只移动该距离，不能重置为新起卷。
      expect(
        (projected(paint()) - projected(before) - Offset(rect.width * .08, 0))
            .distance,
        lessThan(.01),
      );
      expect(paint().cornerWeight, before.cornerWeight);
      expect(paint().images.first, same(original));
      await second.moveBy(Offset(sign * rect.width * .7, 10));
      await tester.pump(const Duration(milliseconds: 300));
      await second.up();
      await waitForPage(tester, 1);
      expect(paint().progress, 0);
      expect(paint().images.first, same(original));
      await tester.tap(find.text('Next'));
      await waitForPage(tester, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  for (final rtl in [false, true]) {
    testWidgets('后翻二维停驻与收尾反向接管保持页面和材质连续 rtl=$rtl', (tester) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: CurlLab()));
      await waitForPage(tester, 1);
      await tester.tap(find.text('Double page'));
      await waitForPage(tester, 1);
      await tester.tap(find.text('Next'));
      await waitForPage(tester, 2);
      CurlPainter paint() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<CurlPainter>()
          .single;
      if (rtl) {
        await tester.tap(find.text('LTR'));
        await tester.pump();
      }
      final sign = rtl ? -1.0 : 1.0;
      final current = paint().images.first;
      final rect = tester.getRect(find.byKey(const Key('curl-surface')));
      final from =
          rect.topLeft +
          Offset(rect.width * (rtl ? .96 : .04), rect.height * .7);
      final first = await tester.startGesture(from);
      await first.moveBy(Offset(sign * rect.width * .08, 0));
      await first.moveTo(from + Offset(sign * rect.width * .58, -30));
      await waitForPage(tester, 1);
      expect(paint().tilt, isNot(0));
      expect(paint().progress, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 300));
      await first.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final before = paint();
      final previous = before.images.first;
      final second = await tester.startGesture(rect.center);
      await second.moveBy(Offset(-sign * rect.width * .08, 0));
      await tester.pump();
      Offset fold(CurlPainter p) {
        final row = CurlGeometry(
          size: rect.size,
          progress: p.progress,
          grabY: p.grabY,
          tilt: p.tilt,
          cornerWeight: p.cornerWeight,
          horizontalWeight: p.horizontalWeight,
          diagonalWeight: p.diagonalWeight,
        ).prepareRow(rect.height * p.grabY);
        return row.project(rect.width).position;
      }

      expect(
        (fold(paint()) - fold(before) + Offset(rect.width * .08, 0)).distance,
        lessThan(.01),
      );
      expect(paint().cornerWeight, before.cornerWeight);
      expect(paint().images.first, same(previous));
      await second.moveBy(Offset(-sign * rect.width * .7, 10));
      await tester.pump(const Duration(milliseconds: 300));
      await second.up();
      await waitForPage(tester, 2);
      expect(paint().images.first, same(current));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('中线斜拖参考传到画笔并可拖回取消', (tester) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: CurlLab()));
    await waitForPage(tester, 1);
    await tester.tap(find.text('Double page'));
    await waitForPage(tester, 1);
    final rect = tester.getRect(find.byKey(const Key('curl-surface')));
    final from = rect.topLeft + Offset(rect.width * .9, rect.height * .5);
    final gesture = await tester.startGesture(from);
    await gesture.moveBy(Offset(-rect.width * .09, 0));
    await tester.pump();
    await gesture.moveTo(from + Offset(-rect.width * .45, -rect.width * .17));
    await tester.pump();
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<CurlPainter>()
        .single;
    expect(painter.diagonalWeight, greaterThan(.99));
    expect(painter.horizontalWeight, 0);
    await gesture.moveTo(from);
    await tester.pump();
    await gesture.up();
    await waitForPage(tester, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('前翻跟随二维抓点，半页完成阈值与曲面进度分离', (tester) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: CurlLab()));
    await waitForPage(tester, 1);
    await tester.tap(find.text('Double page'));
    await waitForPage(tester, 1);
    final surface = find.byKey(const Key('curl-surface'));
    final rect = tester.getRect(surface);
    final box = tester.renderObject<RenderBox>(surface);
    final from = rect.topLeft + Offset(rect.width * 0.9, rect.height * 0.85);
    final target = from + Offset(-rect.width * 0.52, -rect.height * 0.1);
    final gesture = await tester.startGesture(from);
    await gesture.moveBy(Offset(-rect.width * 0.06, 0));
    await tester.pump();
    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<CurlPainter>()
          .single
          .horizontalWeight,
      1,
    );
    await gesture.moveTo(target);
    await tester.pump();
    var paint =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is CurlPainter,
                  ),
                )
                .painter!
            as CurlPainter;
    expect(paint.horizontalWeight, 0);
    final anchor = box.globalToLocal(from);
    final projected =
        CurlGeometry(
          size: box.size,
          progress: paint.progress,
          grabY: paint.grabY,
          tilt: paint.tilt,
          cornerWeight: paint.cornerWeight,
          horizontalWeight: paint.horizontalWeight,
          diagonalWeight: paint.diagonalWeight,
        ).project(
          resolveForwardCurlDrag(
            box.size,
            anchor,
            box.globalToLocal(target),
          ).controlX,
          anchor.dy,
        );
    expect(
      (projected.position - box.globalToLocal(target)).distance,
      lessThan(0.1),
    );
    expect(paint.progress, lessThan(0.5));
    final lifted = target - Offset(0, rect.height * 0.025);
    await gesture.moveTo(lifted);
    await tester.pump();
    paint =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is CurlPainter,
                  ),
                )
                .painter!
            as CurlPainter;
    final liftedPoint =
        CurlGeometry(
          size: box.size,
          progress: paint.progress,
          grabY: paint.grabY,
          tilt: paint.tilt,
          cornerWeight: paint.cornerWeight,
          horizontalWeight: paint.horizontalWeight,
          diagonalWeight: paint.diagonalWeight,
        ).project(
          resolveForwardCurlDrag(
            box.size,
            anchor,
            box.globalToLocal(lifted),
          ).controlX,
          anchor.dy,
        );
    expect(
      (liftedPoint.position - box.globalToLocal(lifted)).distance,
      lessThan(0.1),
    );
    // 慢拖超过半页仍完成，不能把反求出的曲面进度当作手势阈值。
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await waitForPage(tester, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  testWidgets('单双页切换后恢复目标纹理分辨率', (tester) async {
    tester.view.physicalSize = const Size(2200, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: CurlLab()));
    await waitForPage(tester, 1);
    final paints = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is CurlPainter,
    );
    CurlPainter painter() =>
        tester.widget<CustomPaint>(paints).painter! as CurlPainter;
    final originalWidth = painter().images.first.width;
    final originalHeight = painter().images.first.height;
    await tester.tap(find.text('Double page'));
    await waitForPage(tester, 1);
    expect(painter().images.first.width, greaterThan(originalWidth));
    await tester.tap(find.text('Single page'));
    await waitForPage(tester, 1);
    expect(painter().images.first.width, originalWidth);
    expect(painter().images.first.height, originalHeight);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('开启语义树时切换页面源保持稳定', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: CurlLab()));
    await waitForPage(tester, 1);
    await tester.tap(find.byType(DropdownButton<PageKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('comic').last);
    await waitForPage(tester, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('连续前后拖动及取消保持正确页面', (tester) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: CurlLab()));
    await waitForPage(tester, 1);
    await tester.tap(find.text('Next'));
    await waitForPage(tester, 3);
    await tester.tap(find.text('Previous'));
    await waitForPage(tester, 1);
    await tester.tap(find.text('Double page'));
    await waitForPage(tester, 1);
    final surface = find.byKey(const Key('curl-surface'));
    final rect = tester.getRect(surface);
    final from = rect.centerRight - const Offset(30, 0);
    final gesture = await tester.startGesture(from);
    await gesture.moveBy(Offset(-rect.width * 0.8, 0));
    await tester.pump();
    await gesture.up();
    await waitForPage(tester, 2);

    final back = await tester.startGesture(
      rect.centerLeft + const Offset(30, 0),
    );
    await back.moveBy(Offset(rect.width * 0.8, 0));
    // 相邻页准备尚未完成就松手，仍应保留最终拖动距离。
    await back.up();
    await waitForPage(tester, 1);

    final cancelled = await tester.startGesture(from);
    await cancelled.moveBy(Offset(-rect.width * 0.6, 0));
    await tester.pump();
    await cancelled.cancel();
    await waitForPage(tester, 1);
    expect(find.textContaining('· page 1 ·'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await waitForPage(tester, 2);
    final backCancelled = await tester.startGesture(
      rect.centerLeft + const Offset(30, 0),
    );
    await backCancelled.moveBy(Offset(rect.width * 0.6, 0));
    await backCancelled.cancel();
    await waitForPage(tester, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  testWidgets('自动采用网格，切换后端保留页码纹理与方向，模式切换保留选择', (tester) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: CurlLab()));
    await waitForPage(tester, 1);
    final meshPaints = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is CurlPainter,
    );
    final shaderPaints = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is CurlShaderPainter,
    );
    expect(meshPaints, findsOneWidget);
    await tester.tap(find.text('Next'));
    await waitForPage(tester, 3);
    await tester.tap(find.text('LTR'));
    await tester.pump();
    final original =
        tester.widget<CustomPaint>(meshPaints).painter! as CurlPainter;
    final images = List.of(original.images);
    final selector = find.byKey(const Key('curl-renderer-choice'));
    expect(
      tester.widget<DropdownButton<CurlRendererChoice>>(selector).onChanged,
      isNotNull,
    );
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shader').last);
    await waitForPage(tester, 3);
    final shader =
        tester.widget<CustomPaint>(shaderPaints).painter! as CurlShaderPainter;
    expect(shader.rtl, true);
    for (var i = 0; i < images.length; i++) {
      expect(shader.images[i], same(images[i]));
    }
    await tester.tap(find.text('Double page'));
    await waitForPage(tester, 1);
    await tester.tap(find.byType(DropdownButton<PageKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('comic').last);
    await waitForPage(tester, 1);
    expect(shaderPaints, findsOneWidget);
    expect(
      tester.widget<DropdownButton<CurlRendererChoice>>(selector).value,
      CurlRendererChoice.shader,
    );
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auto (mesh)').last);
    await waitForPage(tester, 1);
    expect(meshPaints, findsOneWidget);
    expect(
      (tester.widget<CustomPaint>(meshPaints).painter! as CurlPainter).rtl,
      true,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('shader 准备失败保留原后端与页面，仍可继续翻页', (tester) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CurlLab(loadShader: () async => throw StateError('unavailable')),
      ),
    );
    await waitForPage(tester, 1);
    final selector = find.byKey(const Key('curl-renderer-choice'));
    expect(
      tester.widget<DropdownButton<CurlRendererChoice>>(selector).onChanged,
      isNotNull,
    );
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shader').last);
    await waitForPage(tester, 1);
    expect(find.textContaining('Renderer switch failed'), findsOneWidget);
    expect(
      tester.widget<DropdownButton<CurlRendererChoice>>(selector).value,
      CurlRendererChoice.automatic,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CurlPainter,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Next'));
    await waitForPage(tester, 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
