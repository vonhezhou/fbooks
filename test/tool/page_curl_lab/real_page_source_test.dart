import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';

import 'package:fbooks/domain/reading/flow_document.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:fbooks/features/reader/presentation/flow_reader_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/real_page_source.dart';
import '../../../tool/page_curl_lab/page_sources.dart';

void main() {
  testWidgets(
    'real CBZ contains aspect ratio and uses blank paper beyond end',
    (tester) async {
      await tester.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp(
          'curl-real-source-',
        );
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xffff0000), BlendMode.src);
        final picture = recorder.endRecording();
        final original = await picture.toImage(2, 4);
        picture.dispose();
        final png = (await original.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        original.dispose();
        final file = File('${directory.path}/sample.cbz');
        await file.writeAsBytes(
          ZipEncoder().encode(
            Archive()..addFile(ArchiveFile('1.png', png.length, png)),
          ),
        );
        final source = RealPageSource(paths: {PageKind.comic: file.path});
        try {
          await source.open(PageKind.comic, const Size(10, 10));
          expect(source.pageCount, 1);
          final page = await source.load(0, 1);
          final pixels = (await page.toByteData())!.buffer.asUint8List();
          expect(pixels.sublist(0, 4), [255, 255, 255, 255]);
          expect(pixels.sublist((5 * 10 + 5) * 4, (5 * 10 + 5) * 4 + 4), [
            255,
            0,
            0,
            255,
          ]);
          page.dispose();
          // 布局变化复用文件句柄，不重新按路径打开或解析源文件。
          final moved = await file.rename('${directory.path}/moved.cbz');
          await source.open(PageKind.comic, const Size(20, 10));
          expect(source.pageCount, 1);
          expect(source.metadata['source_session_reused'], true);
          final resized = await source.load(0, 1);
          expect(resized.width, 20);
          expect(resized.height, 10);
          resized.dispose();
          await moved.rename(file.path);
          final blank = await source.load(1, 1);
          final blankPixels = (await blank.toByteData())!.buffer.asUint8List();
          expect(blankPixels.every((v) => v == 255), true);
          blank.dispose();
          await expectLater(source.load(-1, 1), throwsRangeError);
          await source.closeSession();
          await file.writeAsBytes([1, 2, 3]);
          await expectLater(
            source.open(PageKind.comic, const Size(10, 10)),
            throwsA(anything),
          );
          expect(source.pageCount, 0);
        } finally {
          await source.closeSession();
          source.dispose();
          await directory.delete(recursive: true);
        }
      });
    },
  );

  testWidgets('captures distinct production EPUB pages at fixed texture size', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final source = RealPageSource()
      ..size = const Size(300, 480)
      ..chapter = FlowChapter(
        index: 3,
        title: 'Chapter',
        text: 'Paragraph. ' * 3000,
        transitionalHtml: '<p>${'Paragraph with real pagination. ' * 3000}</p>',
      );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RealPageHost(
          source: source,
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(source.pagination!.pageCount, greaterThan(10));
    expect(find.bySemanticsLabel(RegExp('Chapter|Paragraph')), findsNothing);
    Future<ui.Image> capture(int index) async {
      final future = source.capturePage(index, 1.5);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      return future;
    }

    final first = (await tester.runAsync(() => capture(0)))!;
    await tester.pump();
    // 捕获后宿主退出绘制，但分页状态保留，下一页仍可重新捕获。
    expect(find.byKey(source.boundary), findsNothing);
    final second = (await tester.runAsync(() => capture(1)))!;
    expect(first.width, 450);
    expect(first.height, 720);
    expect(source.pagination!.pageIndex, 1);
    final a = await tester.runAsync(() => first.toByteData());
    final b = await tester.runAsync(() => second.toByteData());
    expect(
      a!.buffer.asUint8List(),
      isNot(orderedEquals(b!.buffer.asUint8List())),
    );
    first.dispose();
    second.dispose();
    for (final index in [2, 3, 4, 5, 4, 3]) {
      final image = (await tester.runAsync(() => capture(index)))!;
      expect(source.pagination!.pageIndex, index);
      image.dispose();
      await tester.pump();
      expect(find.byKey(source.boundary), findsNothing);
    }
    // 从 EPUB 切换到无捕获树的格式时，语义父节点结构保持稳定。
    await source.open(PageKind.comic, const Size(300, 480));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(FlowChapterRenderer), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    source.dispose();
    semantics.dispose();
  });
}
