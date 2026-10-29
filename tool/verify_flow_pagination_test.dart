import 'dart:io';
import 'dart:ui' as ui;

import 'package:fbooks/data/reader/local_flow_reading_session.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/reading/flow_document.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/text_reading_preferences.dart';
import 'package:fbooks/features/reader/presentation/flow_content_viewport.dart';
import 'package:fbooks/features/reader/presentation/flow_reader_page.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 使用本机样书验证，不将受版权保护的内容或系统字体复制进仓库。
// flutter test tool/verify_flow_pagination_test.dart
//   --dart-define=FBOOKS_SAMPLE_EPUB=/absolute/path/book.epub
// 可选 FBOOKS_SAMPLE_FONT 与 FBOOKS_SAMPLE_OUTPUT，用于生成中文预览。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const samplePath = String.fromEnvironment('FBOOKS_SAMPLE_EPUB');
  const fontPath = String.fromEnvironment('FBOOKS_SAMPLE_FONT');
  const outputPath = String.fromEnvironment('FBOOKS_SAMPLE_OUTPUT');
  late FlowChapter chapter;

  setUpAll(() async {
    if (samplePath.isEmpty) {
      throw ArgumentError('Supply --dart-define=FBOOKS_SAMPLE_EPUB=...');
    }
    if (fontPath.isNotEmpty) {
      final bytes = ByteData.sublistView(await File(fontPath).readAsBytes());
      // flutter_html 原样保留样书 CSS 中带引号的字体族名。
      for (final family in ['SampleChinese', 'zw', '"zw"']) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
    }
    final session = await LocalFlowReadingSessionFactory().open(
      Publication(
        id: 'pagination-sample',
        title: 'Pagination sample',
        source: const LibrarySource(
          id: 'local',
          kind: LibrarySourceKind.local,
          name: 'Local',
        ),
        format: PublicationFormat.epub,
        assets: [
          PublicationAsset(
            id: 'sample-file',
            publicationId: 'pagination-sample',
            kind: PublicationAssetKind.localFile,
            location: Uri.file(samplePath),
          ),
        ],
      ),
    );
    try {
      chapter = await session.loadChapter(0);
      for (var i = 1; i < session.document.chapters.length; i++) {
        final candidate = await session.loadChapter(i);
        if (candidate.text.length > chapter.text.length) chapter = candidate;
      }
      // ignore: avoid_print
      print(
        'Loaded ${session.document.chapters.length} chapters; '
        'longest chapter: ${chapter.index}, ${chapter.text.length} UTF-16 units.',
      );
    } finally {
      await session.close();
    }
  });

  for (final size in [
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('sample EPUB paginates completely at ${size.width}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      FlowPagination? pagination;
      TextOffsetLocator? saved;
      final boundaryKey = GlobalKey();
      Future<void> render({
        TextOffsetLocator? position,
        TextReadingPreferences preferences = TextReadingPreferences.defaults,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              fontFamily: fontPath.isEmpty ? null : 'SampleChinese',
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: RepaintBoundary(
                key: boundaryKey,
                child: ColoredBox(
                  color: Colors.white,
                  child: FlowChapterRenderer(
                    chapter: chapter,
                    initialPosition:
                        position ??
                        TextOffsetLocator(
                          chapterIndex: chapter.index,
                          offset: 0,
                        ),
                    preferences: preferences,
                    onChapterSelected: (_) {},
                    onPositionChanged: (value) => saved = value,
                    onPaginationChanged: (value) => pagination = value,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> capture(String suffix) async {
        if (outputPath.isEmpty) return;
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          image.dispose();
          await Directory(outputPath).create(recursive: true);
          await File('$outputPath/epub-${size.width.toInt()}-$suffix.png')
              .writeAsBytes(bytes.buffer.asUint8List());
        });
      }

      await render();
      expect(pagination!.pageCount, greaterThan(1));
      final initialCount = pagination!.pageCount;
      await capture('first');
      final scrollFinder = find.byKey(const Key('flow-content-scroll'));
      final scroll = tester
          .widget<SingleChildScrollView>(scrollFinder)
          .controller!;
      final viewportTop = tester.getTopLeft(scrollFinder).dy;
      final lines = <({double top, double bottom})>[];
      for (final paragraph in tester.renderObjectList<RenderParagraph>(
        find.byType(RichText),
      )) {
        var offset = 0;
        void collect(InlineSpan span) {
          if (span is TextSpan) {
            final length = span.text?.length ?? 0;
            for (final box in paragraph.getBoxesForSelection(
              TextSelection(baseOffset: offset, extentOffset: offset + length),
            )) {
              lines.add((
                top:
                    paragraph.localToGlobal(Offset(0, box.top)).dy -
                    viewportTop,
                bottom:
                    paragraph.localToGlobal(Offset(0, box.bottom)).dy -
                    viewportTop,
              ));
            }
            offset += length;
            for (final child in span.children ?? <InlineSpan>[]) {
              collect(child);
            }
          } else if (span is PlaceholderSpan) {
            // WidgetSpan 的包围盒可能包含整章 HTML，不是文字行。
            offset++;
          }
        }

        collect(paragraph.text);
      }
      var end = 0.0;
      for (var i = 0; i < initialCount; i++) {
        expect(pagination!.pageIndex, i);
        expect(
          scroll.offset,
          closeTo(end, 0.1),
          reason: 'Pages must be contiguous',
        );
        final clipFinder = find
            .ancestor(of: scrollFinder, matching: find.byType(ClipRect))
            .first;
        final clip = tester.widget<ClipRect>(clipFinder);
        final height = clip.clipper!.getClip(tester.getSize(clipFinder)).height;
        end = scroll.offset + height;
        for (final line in lines) {
          expect(
            line.top < scroll.offset - 0.1 && line.bottom > scroll.offset + 0.1,
            isFalse,
            reason: 'Page starts inside a line',
          );
          expect(
            line.top < end - 0.1 && line.bottom > end + 0.1,
            isFalse,
            reason: 'Page $i ($end) ends inside a line: $line',
          );
        }
        if (i == 1) await capture('second');
        if (i < initialCount - 1) {
          pagination!.onNextPage();
          await tester.pumpAndSettle();
        }
      }
      expect(pagination!.canGoForward, isFalse);
      expect(
        lines.every((line) => line.bottom <= end + 0.1),
        isTrue,
        reason: 'The final page must include the end of the chapter',
      );
      pagination!.onPageSelected(initialCount ~/ 2);
      await tester.pumpAndSettle();
      final anchor = saved!;
      await render(
        preferences: const TextReadingPreferences(fontSize: 26, lineHeight: 2),
      );
      expect(pagination!.pageCount, greaterThan(initialCount));
      expect(saved!.paragraphIndex, anchor.paragraphIndex);
      expect(saved!.characterOffset, anchor.characterOffset);
      await tester.binding.setSurfaceSize(
        Size(size.width + 100, size.height - 100),
      );
      await tester.pumpAndSettle();
      expect(saved!.paragraphIndex, anchor.paragraphIndex);
      expect(saved!.characterOffset, anchor.characterOffset);
      await tester.pumpWidget(const SizedBox());
      await render(position: anchor);
      expect(saved!.paragraphIndex, anchor.paragraphIndex);
      expect(saved!.characterOffset, anchor.characterOffset);
      expect(tester.takeException(), isNull);
      // ignore: avoid_print
      print(
        '${size.width.toInt()} x ${size.height.toInt()}: $initialCount pages; '
        'all page boundaries and reflow/resume anchors verified.',
      );
    });
  }
}
