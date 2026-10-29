import 'package:fbooks/domain/reading/flow_document.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/text_reading_preferences.dart';
import 'package:fbooks/features/reader/presentation/flow_reader_page.dart';
import 'package:fbooks/features/reader/presentation/flow_content_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fbooks/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'EPUB typography preferences override chapter CSS during reflow',
    (tester) async {
      FlowPagination? pagination;
      final chapter = FlowChapter(
        index: 0,
        title: 'Styled chapter',
        text: '',
        transitionalHtml:
            '<style>p { font-size: 12px; line-height: 100%; color: #ffffff; }</style>'
            '<p style="font-size: 10px; line-height: 100%">'
            '${List.filled(300, '阅读排版内容。').join()}</p>',
      );
      Future<void> render(double fontSize, double lineHeight) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FlowChapterRenderer(
                chapter: chapter,
                initialPosition: const TextOffsetLocator(
                  chapterIndex: 0,
                  offset: 0,
                ),
                preferences: TextReadingPreferences(
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                  appearance: TextReadingAppearance.dark,
                ),
                onPositionChanged: (_) {},
                onChapterSelected: (_) {},
                onPaginationChanged: (value) => pagination = value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await render(18, 1.3);
      final smallPageCount = pagination!.pageCount;
      await render(28, 2.1);
      expect(pagination!.pageCount, greaterThan(smallPageCount));
      final body = tester
          .renderObjectList<RenderParagraph>(find.byType(RichText))
          .firstWhere(
            (paragraph) => paragraph.text.toPlainText().contains('阅读排版内容'),
          );
      final position = body.getPositionForOffset(Offset.zero);
      final style = body.text.getSpanForPosition(position)!.style!;
      expect(style.fontSize, 28);
      expect(style.height, 2.1);
      expect(style.color, const Color(0xFFE0E0E0));
    },
  );

  final text = List.generate(
    100,
    (i) =>
        'Paragraph $i: 阅读内容随窗口宽度换行。 👨‍👩‍👧‍👦 café ABCDEFGHIJKLMNOPQRSTUVWXYZ\n',
  ).join();
  TextOffsetLocator? saved;
  Widget reader({
    TextReadingPreferences preferences = TextReadingPreferences.defaults,
    TextOffsetLocator position = const TextOffsetLocator(
      chapterIndex: 0,
      offset: 0,
    ),
    bool html = false,
  }) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: FlowChapterRenderer(
        chapter: FlowChapter(
          index: 0,
          title: 'A chapter',
          text: text,
          transitionalHtml: html
              ? '<p>${text.replaceAll('\n', '</p><p>')}</p>'
              : null,
        ),
        initialPosition: position,
        preferences: preferences,
        onPositionChanged: (value) => saved = value,
        onChapterSelected: (_) {},
      ),
    ),
  );

  for (final width in [390.0, 768.0, 1440.0]) {
    for (final html in [false, true]) {
      testWidgets(
        '${html ? 'EPUB' : 'TXT'} paginates at $width without cutting lines',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 700));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(reader(html: html));
          await tester.pumpAndSettle();
          final scrollFinder = find.byKey(const Key('flow-content-scroll'));
          expect(tester.getSize(scrollFinder).width, width - 48);
          final scroll = tester
              .widget<SingleChildScrollView>(scrollFinder)
              .controller!;
          expect(scroll.offset, 0);
          var pages = 0;
          var previousEnd = 0.0;
          while (true) {
            final clipFinder = find
                .ancestor(of: scrollFinder, matching: find.byType(ClipRect))
                .first;
            final clip = tester.widget<ClipRect>(clipFinder);
            final rect = clip.clipper!.getClip(tester.getSize(clipFinder));
            final origin = tester.getTopLeft(scrollFinder);
            expect(scroll.offset, closeTo(previousEnd, 0.1));
            previousEnd = scroll.offset + rect.height;
            for (final paragraph in tester.renderObjectList<RenderParagraph>(
              find.byType(RichText),
            )) {
              if (!paragraph.text.toPlainText().contains('Paragraph')) continue;
              for (final box in paragraph.getBoxesForSelection(
                TextSelection(
                  baseOffset: 0,
                  extentOffset: paragraph.text.toPlainText().length,
                ),
              )) {
                final top =
                    paragraph.localToGlobal(Offset(0, box.top)).dy - origin.dy;
                final bottom =
                    paragraph.localToGlobal(Offset(0, box.bottom)).dy -
                    origin.dy;
                expect(
                  top < rect.height - 0.1 && bottom > rect.height + 0.1,
                  isFalse,
                  reason: 'Page ends inside a line',
                );
                expect(
                  top < -0.1 && bottom > 0.1,
                  isFalse,
                  reason: 'Page starts inside a line',
                );
              }
            }
            pages++;
            final next = tester.widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            );
            if (next.onPressed == null) break;
            await tester.tap(find.byTooltip('Next page'));
            await tester.pumpAndSettle();
            expect(pages, lessThan(100));
          }
          expect(pages, greaterThan(1));
          expect(saved!.characterOffset, isNotNull);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pumpAndSettle();
          expect(scroll.offset, lessThan(saved!.offset + 1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('reflows, switches modes and restores a text anchor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(reader());
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
    }
    final anchor = saved!;
    await tester.binding.setSurfaceSize(const Size(1440, 800));
    await tester.pumpAndSettle();
    expect(saved!.paragraphIndex, anchor.paragraphIndex);
    expect(saved!.characterOffset, lessThanOrEqualTo(anchor.characterOffset!));
    expect(saved!.characterOffset, greaterThan(0));
    final reflowed = saved!;
    await tester.pumpWidget(
      reader(
        preferences: const TextReadingPreferences(
          mode: TextReadingMode.scroll,
          fontSize: 24,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flow-page-progress')), findsNothing);
    expect(saved!.characterOffset, closeTo(reflowed.characterOffset!, 100));
    await tester.drag(
      find.byKey(const Key('flow-content-scroll')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(saved!.characterOffset, greaterThan(reflowed.characterOffset!));
    final resume = saved!;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(reader(position: resume));
    await tester.pumpAndSettle();
    expect(saved!.paragraphIndex, resume.paragraphIndex);
    expect(saved!.characterOffset, lessThanOrEqualTo(resume.characterOffset!));
    expect(saved!.characterOffset, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('clamps an old pixel position beyond the last page', (
    tester,
  ) async {
    await tester.pumpWidget(
      reader(
        position: const TextOffsetLocator(chapterIndex: 0, offset: 1 << 31),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNotNull,
    );
    expect(saved!.offset, lessThan(1 << 31));
    expect(tester.takeException(), isNull);
  });

  testWidgets('equivalent locator instances retain the anchor on rebuild', (
    tester,
  ) async {
    TextOffsetLocator start() => TextOffsetLocator(chapterIndex: 0, offset: 0);
    await tester.pumpWidget(reader(position: start(), html: true));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
    }
    final anchor = saved!;
    await tester.pumpWidget(
      reader(
        position: start(),
        html: true,
        preferences: const TextReadingPreferences(fontSize: 26, lineHeight: 2),
      ),
    );
    await tester.pumpAndSettle();
    expect(saved!.paragraphIndex, anchor.paragraphIndex);
    expect(saved!.characterOffset, anchor.characterOffset);

    // 真正的外部跳转仍需生效。
    await tester.pumpWidget(reader(position: anchor, html: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(reader(position: start(), html: true));
    await tester.pumpAndSettle();
    expect(saved!.offset, 0);
    expect(tester.takeException(), isNull);
  });
}
