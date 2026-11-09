import 'dart:async';

import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/reader/flow_reading_session.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/reading_progress_repository.dart';
import 'package:fbooks/domain/reading/flow_document.dart';
import 'package:fbooks/domain/reading/text_reading_preferences.dart';
import 'package:fbooks/domain/reading/text_reading_preferences_repository.dart';
import 'package:fbooks/features/reader/presentation/flow_reader_page.dart';
import 'package:fbooks/features/reader/presentation/reader_chrome.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'cancelled boundary preview preserves the previous chapter restore anchor',
    (tester) async {
      await tester.pumpWidget(
        _readerApp(
          FlowDocument(
            publicationId: _publicationId,
            chapters: [
              FlowChapter(
                index: 0,
                title: 'Long first',
                text: List.filled(160, 'Original chapter anchor.\n').join(),
              ),
              const FlowChapter(
                index: 1,
                title: 'Second',
                text: 'Current source',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Table of contents'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-reader-toc-1')));
      await tester.pumpAndSettle();
      final bounds = tester.getRect(
        find.byKey(const Key('text-reader-content')),
      );
      final drag = await tester.startGesture(
        Offset(bounds.left + 40, bounds.center.dy),
      );
      await drag.moveTo(
        Offset(bounds.left + 100, bounds.center.dy + 10),
        timeStamp: const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();
      await drag.up(timeStamp: const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Current source').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Table of contents'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-reader-toc-0')));
      await tester.pumpAndSettle();
      expect(_pageInput(tester).controller!.text, '1');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'chapter handoff keeps the same viewport while pagination becomes ready',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(_readerApp(_documentWithTableOfContents));
      await tester.pumpAndSettle();
      final bounds = tester.getRect(
        find.byKey(const Key('text-reader-content')),
      );
      await tester.tap(find.byTooltip('Table of contents'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-reader-toc-1')));
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          tester.getRect(find.byKey(const Key('text-reader-content'))),
          bounds,
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('Continue').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'retains only adjacent chapter renderers and saves only the active position',
    (tester) async {
      final repository = _ReadingProgressRepository();
      await tester.pumpWidget(
        _readerApp(
          FlowDocument(
            publicationId: _publicationId,
            chapters: [
              for (var i = 0; i < 5; i++)
                FlowChapter(index: i, title: 'Chapter $i', text: 'Content $i'),
            ],
          ),
          progressRepository: repository,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<FlowChapterRenderer>(find.byType(FlowChapterRenderer))
            .map((w) => w.chapter.index)
            .toSet(),
        {0, 1},
      );
      await tester.tap(find.byTooltip('Table of contents'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-reader-toc-3')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester
            .widgetList<FlowChapterRenderer>(find.byType(FlowChapterRenderer))
            .map((w) => w.chapter.index)
            .toSet(),
        {2, 3, 4},
      );
      expect((repository.saved!.locator as TextOffsetLocator).chapterIndex, 3);
      expect(find.text('Content 3').hitTestable(), findsOneWidget);
      expect(find.text('Content 2').hitTestable(), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed cached neighbor can retry and the prepared renderer survives commit',
    (tester) async {
      var attempts = 0;
      final repository = _ReadingProgressRepository();
      await tester.pumpWidget(
        _readerApp(
          _documentWithTableOfContents,
          progressRepository: repository,
          onLoadChapter: (index) {
            if (index == 1 && ++attempts == 1) {
              throw StateError('Transient chapter failure');
            }
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      final bounds = tester.getRect(
        find.byKey(const Key('text-reader-content')),
      );
      final drag = await tester.startGesture(
        Offset(bounds.right - 40, bounds.center.dy),
      );
      await drag.moveTo(Offset(bounds.left + 40, bounds.center.dy + 20));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader-page-curl')), findsOneWidget);
      final target = find.byWidgetPredicate(
        (w) => w is FlowChapterRenderer && w.chapter.index == 1,
      );
      final prepared = tester.element(target);
      expect((repository.saved!.locator as TextOffsetLocator).chapterIndex, 0);
      await drag.up();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.element(target), same(prepared));
      expect(attempts, 2);
      expect((repository.saved!.locator as TextOffsetLocator).chapterIndex, 1);
      expect(find.text('Continue').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'page progress updates do not reload or rebuild chapter content',
    (tester) async {
      var loads = 0;
      await tester.pumpWidget(
        _readerApp(
          FlowDocument(
            publicationId: _publicationId,
            chapters: [
              FlowChapter(
                index: 0,
                title: 'Long chapter',
                text: List.filled(
                  160,
                  'Stable chapter content and pagination.\n',
                ).join(),
              ),
            ],
          ),
          onLoadChapter: (_) => loads++,
        ),
      );
      await tester.pumpAndSettle();
      final initialLoads = loads;
      expect(initialLoads, greaterThan(0));
      for (var page = 2; page <= 3; page++) {
        await tester.tap(find.byTooltip('Next page'));
        await tester.pumpAndSettle();
        expect(_pageInput(tester).controller!.text, '$page');
        expect(loads, initialLoads);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'curl previews chapters without saving and commits correct anchors in both directions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _ReadingProgressRepository();
      await tester.pumpWidget(
        _readerApp(
          _documentWithTableOfContents,
          progressRepository: repository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect((repository.saved!.locator as TextOffsetLocator).chapterIndex, 0);
      final bounds = tester.getRect(
        find.byKey(const Key('text-reader-content')),
      );
      final forward = await tester.startGesture(
        Offset(bounds.right - 40, bounds.center.dy),
      );
      await forward.moveTo(Offset(bounds.left + 70, bounds.center.dy + 20));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader-page-curl')), findsOneWidget);
      expect((repository.saved!.locator as TextOffsetLocator).chapterIndex, 0);
      await forward.up();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Continue'), findsOneWidget);
      expect((repository.saved!.locator as TextOffsetLocator).chapterIndex, 1);
      final backward = await tester.startGesture(
        Offset(bounds.left + 40, bounds.center.dy),
      );
      await backward.moveTo(Offset(bounds.right - 60, bounds.center.dy + 20));
      await tester.pumpAndSettle();
      expect((repository.saved!.locator as TextOffsetLocator).chapterIndex, 1);
      await backward.up();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Read'), findsOneWidget);
      expect((repository.saved!.locator as TextOffsetLocator).chapterIndex, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'page buttons cross chapter boundaries and return to the last page',
    (tester) async {
      final repository = _ReadingProgressRepository();
      await tester.pumpWidget(
        _readerApp(
          FlowDocument(
            publicationId: _publicationId,
            chapters: [
              FlowChapter(
                index: 0,
                title: 'Long first',
                text: List.filled(100, 'First chapter line\n').join(),
              ),
              const FlowChapter(index: 1, title: 'Second', text: 'Arrival'),
            ],
          ),
          progressRepository: repository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Table of contents'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-reader-toc-1')));
      await tester.pumpAndSettle();
      expect(find.text('Arrival'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous page'));
      await tester.pumpAndSettle();
      final page = int.parse(_pageInput(tester).controller!.text);
      final count = tester
          .widget<ReaderPageNavigation>(find.byType(ReaderPageNavigation))
          .pageCount;
      expect(page, count);
      expect(page, greaterThan(1));
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Arrival'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect((repository.saved!.locator as TextOffsetLocator).chapterIndex, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'waits for saved progress and keeps reading after a write failure',
    (tester) async {
      final pending = Completer<ReadingProgress?>();
      final repository = _ReadingProgressRepository(
        pending: pending.future,
        failWrites: true,
      );
      await tester.pumpWidget(
        _readerApp(
          _documentWithTableOfContents,
          progressRepository: repository,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(repository.saved, isNull);
      expect(find.text('Read'), findsNothing);
      pending.complete(
        ReadingProgress(
          publicationId: _publicationId,
          locator: const TextOffsetLocator(chapterIndex: 1, offset: 0),
          updatedAt: DateTime(2026),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byTooltip('Previous page'));
      await tester.pumpAndSettle();
      expect(find.text('Read'), findsOneWidget);
      expect(tester.takeException(), isNull);
      repository.failWrites = false;
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect((repository.saved!.locator as TextOffsetLocator).chapterIndex, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('follows an internal EPUB link rendered from XHTML', (
    tester,
  ) async {
    await tester.pumpWidget(
      _readerApp(
        const FlowDocument(
          publicationId: _publicationId,
          chapters: [
            FlowChapter(
              index: 0,
              title: 'First',
              text: '',
              transitionalHtml: '<p><a href="fbooks://chapter/1">Read the next chapter</a></p>',
            ),
            FlowChapter(index: 1, title: 'Second', text: 'Arrival'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read the next chapter'));
    await tester.pumpAndSettle();

    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Arrival'), findsOneWidget);
  });

  testWidgets('renders EPUB XHTML images and tables', (tester) async {
    await tester.pumpWidget(
      _readerApp(
        FlowDocument(
          publicationId: _publicationId,
          chapters: [
            FlowChapter(
              index: 0,
              title: 'Illustrated data',
              text: '',
              transitionalHtml:
                  '<p><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==" /></p>'
                  '<table><tr><th>Year</th><th>Sales</th></tr>'
                  '<tr><td>2025</td><td>42</td></tr></table>',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Sales'), findsOneWidget);
  });

  testWidgets('uses a full-width footer and persistent desktop outline', (
    tester,
  ) async {
    await _setWindowSize(tester, const Size(1200, 820));
    await tester.pumpWidget(
      _readerApp(
        const FlowDocument(
          publicationId: _publicationId,
          chapters: [FlowChapter(index: 0, title: 'First', text: 'Read')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('text-reader-desktop-controls')),
      findsOneWidget,
    );
    final footer = tester.getRect(
      find.byKey(const Key('text-reader-desktop-controls')),
    );
    expect(footer.left, 0);
    expect(footer.right, 1200);
    expect(footer.bottom, 820);
    final outline = tester.getRect(
      find.byKey(const Key('text-reader-desktop-table-of-contents')),
    );
    expect(outline.width, 320);
    expect(outline.bottom, footer.top);
    expect(find.byTooltip('Reading settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a dark right-side panel for desktop settings', (
    tester,
  ) async {
    await _setWindowSize(tester, const Size(1200, 820));
    await tester.pumpWidget(
      _readerApp(
        const FlowDocument(
          publicationId: _publicationId,
          chapters: [FlowChapter(index: 0, title: 'First', text: 'Read')],
        ),
        preferences: const TextReadingPreferences(
          appearance: TextReadingAppearance.dark,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reading settings'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('text-reader-desktop-settings')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopRight(find.byKey(const Key('text-reader-desktop-settings')))
          .dx,
      1200,
    );
    final surface = tester.widget<Material>(
      find.byKey(const Key('text-reading-settings-surface')),
    );
    expect(surface.color, const Color(0xFF1C1B1F));
  });

  testWidgets('uses a bottom sheet for compact settings', (tester) async {
    await _setWindowSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      _readerApp(
        const FlowDocument(
          publicationId: _publicationId,
          chapters: [FlowChapter(index: 0, title: 'First', text: 'Read')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reading settings'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('text-reader-desktop-settings')), findsNothing);
  });

  testWidgets('uses a dark left-side panel for the desktop table of contents', (
    tester,
  ) async {
    await _setWindowSize(tester, const Size(1200, 820));
    await tester.pumpWidget(
      _readerApp(
        _documentWithTableOfContents,
        preferences: const TextReadingPreferences(
          appearance: TextReadingAppearance.dark,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final panel = find.byKey(
      const Key('text-reader-desktop-table-of-contents'),
    );
    expect(panel, findsOneWidget);
    expect(tester.getTopLeft(panel).dx, 0);
    final surface = tester.widget<Material>(
      find.byKey(const Key('text-reader-table-of-contents-surface')),
    );
    expect(surface.color, const Color(0xFF1C1B1F));
    expect(tester.getSize(panel).width, 320);
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.byTooltip('Close table of contents'));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    await tester.tap(find.byTooltip('Table of contents'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second chapter'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    expect(panel, findsOneWidget);
  });

  for (final html in [false, true]) {
    testWidgets(
      '${html ? 'EPUB' : 'TXT'} page input follows real pagination and preserves its anchor on resize',
      (tester) async {
        await _setWindowSize(tester, const Size(1440, 1000));
        final repository = _ReadingProgressRepository();
        final text = List.generate(
          100,
          (index) =>
              'Paragraph $index. A long chapter remains readable when the window changes size.',
        ).join('\n');
        await tester.pumpWidget(
          _readerApp(
            FlowDocument(
              publicationId: _publicationId,
              chapters: [
                FlowChapter(
                  index: 0,
                  title: 'A long chapter',
                  text: text,
                  transitionalHtml: html
                      ? '<p>${text.replaceAll('\n', '</p><p>')}</p>'
                      : null,
                ),
              ],
            ),
            progressRepository: repository,
          ),
        );
        await tester.pumpAndSettle();
        final navigation = tester.widget<ReaderPageNavigation>(
          find.byType(ReaderPageNavigation),
        );
        expect(navigation.currentPage, 1);
        expect(navigation.pageCount, greaterThan(3));
        expect(
          tester
              .widget<Text>(find.byKey(const Key('text-reader-position')))
              .data,
          contains('Chapter 1 of 1'),
        );

        await tester.enterText(find.byKey(const Key('reader-page-input')), '3');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(_pageInput(tester).controller!.text, '3');
        await tester.pump(const Duration(milliseconds: 500));
        final anchor = repository.saved!.locator as TextOffsetLocator;
        expect(anchor.offset, greaterThan(0));

        await tester.enterText(
          find.byKey(const Key('reader-page-input')),
          '${navigation.pageCount + 1}',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(_pageInput(tester).controller!.text, '3');

        await _setWindowSize(tester, const Size(768, 1000));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 500));
        final resized = repository.saved!.locator as TextOffsetLocator;
        expect(resized.paragraphIndex, anchor.paragraphIndex);
        expect(resized.characterOffset, anchor.characterOffset);
        expect(
          find.byKey(const Key('text-reader-desktop-table-of-contents')),
          findsNothing,
        );
        expect(
          tester.getSize(find.byKey(const Key('flow-content-scroll'))).width,
          720,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'settings switch to continuous reading without discarding the text anchor',
    (tester) async {
      await _setWindowSize(tester, const Size(390, 844));
      final repository = _ReadingProgressRepository();
      final preferences = _TextReadingPreferencesRepository(
        TextReadingPreferences.defaults,
      );
      await tester.pumpWidget(
        _readerApp(
          FlowDocument(
            publicationId: _publicationId,
            chapters: [
              FlowChapter(
                index: 0,
                title: 'Long chapter',
                text: List.generate(
                  100,
                  (index) =>
                      'Paragraph $index. Keep the reader at this text anchor.',
                ).join('\n'),
              ),
            ],
          ),
          progressRepository: repository,
          preferencesRepository: preferences,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      final anchor = repository.saved!.locator as TextOffsetLocator;

      await tester.tap(find.byTooltip('Reading settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<TextReadingMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuous scroll').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(preferences.preferences.mode, TextReadingMode.scroll);
      expect(
        preferences.preferences.fontSize,
        TextReadingPreferences.defaults.fontSize,
      );
      expect(
        preferences.preferences.horizontalPadding,
        TextReadingPreferences.defaults.horizontalPadding,
      );
      expect(find.byType(ReaderPageNavigation), findsNothing);
      expect(find.byTooltip('Next chapter'), findsOneWidget);
      final resumed = repository.saved!.locator as TextOffsetLocator;
      expect(resumed.paragraphIndex, anchor.paragraphIndex);
      expect(resumed.characterOffset, anchor.characterOffset);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('uses a full-screen dialog for the compact table of contents', (
    tester,
  ) async {
    await _setWindowSize(tester, const Size(390, 844));
    await tester.pumpWidget(_readerApp(_documentWithTableOfContents));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Table of contents'));
    await tester.pumpAndSettle();

    final surface = find.byKey(
      const Key('text-reader-table-of-contents-surface'),
    );
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.getSize(surface), tester.getSize(find.byType(MaterialApp)));
  });
}

Future<void> _setWindowSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });
}

TextField _pageInput(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const Key('reader-page-input')));

const _publicationId = 'linked-book';

const _publication = Publication(
  id: _publicationId,
  source: LibrarySource(
    id: 'local-library',
    kind: LibrarySourceKind.local,
    name: 'Local library',
  ),
  title: 'Linked book',
  format: PublicationFormat.epub,
);

const _documentWithTableOfContents = FlowDocument(
  publicationId: _publicationId,
  chapters: [
    FlowChapter(index: 0, title: 'First', text: 'Read'),
    FlowChapter(index: 1, title: 'Second', text: 'Continue'),
  ],
  tableOfContents: [
    FlowTableOfContentsEntry(title: 'First chapter', chapterIndex: 0),
    FlowTableOfContentsEntry(title: 'Second chapter', chapterIndex: 1),
  ],
);

Widget _readerApp(
  FlowDocument document, {
  TextReadingPreferences preferences = TextReadingPreferences.defaults,
  _ReadingProgressRepository? progressRepository,
  _TextReadingPreferencesRepository? preferencesRepository,
  ValueChanged<int>? onLoadChapter,
}) => ProviderScope(
  overrides: [
    publicationRepositoryProvider.overrideWithValue(
      _PublicationRepository(_publication),
    ),
    flowReadingSessionFactoryProvider.overrideWithValue(
      _FlowReadingSessionFactory(document, onLoadChapter: onLoadChapter),
    ),
    readingProgressRepositoryProvider.overrideWithValue(
      progressRepository ?? _ReadingProgressRepository(),
    ),
    textReadingPreferencesRepositoryProvider.overrideWithValue(
      preferencesRepository ?? _TextReadingPreferencesRepository(preferences),
    ),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: FlowReaderPage(publicationId: _publicationId, title: 'Linked book'),
  ),
);

class _PublicationRepository implements PublicationRepository {
  const _PublicationRepository(this.publication);

  final Publication publication;

  @override
  Future<void> delete(PublicationId id) => throw UnimplementedError();

  @override
  Future<Publication?> findById(PublicationId id) async => publication;

  @override
  Future<Publication?> findByAssetLocation(Uri location) =>
      throw UnimplementedError();

  @override
  Future<List<Publication>> listPublications() async => [publication];

  @override
  Future<void> save(Publication publication) => throw UnimplementedError();

  @override
  Stream<List<Publication>> watchPublications() => Stream.value([publication]);
}

class _FlowReadingSessionFactory implements FlowReadingSessionFactory {
  const _FlowReadingSessionFactory(this.document, {this.onLoadChapter});

  final ValueChanged<int>? onLoadChapter;

  final FlowDocument document;

  @override
  Future<FlowReadingSession> open(Publication publication) async =>
      _FlowReadingSession(document, onLoadChapter: onLoadChapter);
}

class _FlowReadingSession implements FlowReadingSession {
  const _FlowReadingSession(this.document, {this.onLoadChapter});

  final ValueChanged<int>? onLoadChapter;

  @override
  final FlowDocument document;

  @override
  Future<FlowChapter> loadChapter(int index) async {
    onLoadChapter?.call(index);
    return document.chapters[index];
  }

  @override
  Future<void> close() async {}
}

class _ReadingProgressRepository implements ReadingProgressRepository {
  _ReadingProgressRepository({this.pending, this.failWrites = false});
  final Future<ReadingProgress?>? pending;
  bool failWrites;
  ReadingProgress? saved;
  @override
  Future<ReadingProgress?> load(PublicationId publicationId) async =>
      pending == null ? null : await pending;

  @override
  Future<void> save(ReadingProgress progress) async {
    if (failWrites) throw StateError('Storage unavailable');
    saved = progress;
  }
}

class _TextReadingPreferencesRepository
    implements TextReadingPreferencesRepository {
  _TextReadingPreferencesRepository(this.preferences);

  TextReadingPreferences preferences;

  @override
  Future<TextReadingPreferences> load() async => preferences;

  @override
  Future<void> save(TextReadingPreferences preferences) async {
    this.preferences = preferences;
  }
}
