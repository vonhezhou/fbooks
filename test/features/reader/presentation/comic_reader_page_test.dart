import 'dart:io';
import 'dart:typed_data';

import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/reader/comic_reader_session.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/collection/book_collection.dart';
import 'package:fbooks/domain/collection/book_collection_repository.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:fbooks/domain/reading/comic_document.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding_repository.dart';
import 'package:fbooks/domain/reading/comic_reading_preferences.dart';
import 'package:fbooks/domain/reading/comic_reading_preferences_repository.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress_repository.dart';
import 'package:fbooks/features/reader/presentation/comic_reader_page.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(800, 1000),
    const Size(1200, 820),
  ]) {
    testWidgets(
      'overlays controls without shrinking the comic at ${size.width}',
      (tester) async {
        await _setWindow(tester, size);
        await _pumpReader(tester);

        final stage = find.byKey(
          Key(
            size.width >= 900
                ? 'comic-reader-desktop-stage'
                : 'comic-reader-compact-stage',
          ),
        );
        expect(tester.getRect(stage), Offset.zero & size);
        expect(
          tester.getTopLeft(find.byKey(const Key('comic-reader-toolbar'))),
          Offset.zero,
        );
        expect(find.text('1 / 3'), findsOneWidget);
        expect(find.byTooltip('Reading settings'), findsOneWidget);
        expect(
          tester.widget<Image>(find.byType(Image).first).fit,
          BoxFit.contain,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'opens theme-aware comic settings and persists archive encoding',
    (tester) async {
      await _setWindow(tester, const Size(1200, 820));
      final encoding = _ArchiveEncodingRepository();
      await _pumpReader(tester, encoding: encoding);
      await tester.tap(find.byTooltip('Reading settings'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.byKey(const Key('comic-reader-desktop-settings')),
        findsNothing,
      );
      final surface = tester.widget<Material>(
        find.byKey(const Key('comic-reading-settings-surface')),
      );
      expect(
        surface.color,
        Theme.of(
          tester.element(
            find.byKey(const Key('comic-reading-settings-surface')),
          ),
        ).colorScheme.surface,
      );
      await tester.tap(
        find.byType(DropdownButtonFormField<ComicArchiveFileNameEncoding>),
      );
      await tester.pumpAndSettle();
      final unsupported = tester
          .widget<DropdownMenuItem<ComicArchiveFileNameEncoding>>(
            find
                .widgetWithText(
                  DropdownMenuItem<ComicArchiveFileNameEncoding>,
                  'EUC-KR (unavailable)',
                )
                .last,
          );
      expect(unsupported.enabled, false);
      await tester.tap(find.text('GBK').last);
      await tester.pumpAndSettle();
      expect(encoding.values['bobby'], 'gbk');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps direction and layout controls usable in a phone sheet', (
    tester,
  ) async {
    await _setWindow(tester, const Size(390, 844));
    final preferences = _ComicReadingPreferencesRepository();
    await _pumpReader(tester, preferences: preferences);
    await tester.tap(find.byTooltip('Reading settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Right to left'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Double page'));
    await tester.pumpAndSettle();
    expect(preferences.preferences.mode, ComicReadingMode.rightToLeft);
    expect(preferences.preferences.doublePage, isTrue);
    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(tester.widget<PageView>(find.byType(PageView)).reverse, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'restores a saved page and preserves it when controls are toggled',
    (tester) async {
      await _setWindow(tester, const Size(1200, 820));
      final session = _CountingComicReaderSession();
      await _pumpReader(
        tester,
        session: session,
        progress: _ReadingProgressRepository(
          ReadingProgress(
            publicationId: 'bobby',
            locator: ComicPageLocator(1),
            updatedAt: DateTime(2026),
          ),
        ),
      );
      expect(find.text('2 / 3'), findsOneWidget);
      final reads = session.readCalls;

      await tester.tapAt(const Offset(600, 400));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const Key('comic-reader-toolbar-visibility')),
            )
            .opacity,
        0,
      );
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const Key('comic-reader-progress-visibility')),
            )
            .opacity,
        0,
      );
      expect(
        tester.widget<Slider>(find.byKey(const Key('comic-page-slider'))).value,
        1,
      );
      expect(session.readCalls, reads);

      await tester.tapAt(const Offset(600, 400));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const Key('comic-reader-toolbar-visibility')),
            )
            .opacity,
        1,
      );
      expect(find.text('2 / 3'), findsOneWidget);
      expect(session.readCalls, reads);
    },
  );

  testWidgets('maps physical turn buttons to RTL and saves the final page', (
    tester,
  ) async {
    await _setWindow(tester, const Size(1200, 820));
    final progress = _ReadingProgressRepository();
    final collections = _BookCollectionRepository();
    await _pumpReader(
      tester,
      preferences: _ComicReadingPreferencesRepository(
        const ComicReadingPreferences(mode: ComicReadingMode.rightToLeft),
      ),
      progress: progress,
      collections: collections,
    );
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('comic-page-slider'))),
      ),
      TextDirection.rtl,
    );
    expect(_turnButton(tester, 'comic-turn-right').onPressed, isNull);
    expect(_turnButton(tester, 'comic-turn-left').onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('comic-turn-left')));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('comic-turn-left')));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(_turnButton(tester, 'comic-turn-left').onPressed, isNull);
    expect((progress.saved.last.locator as ComicPageLocator).pageIndex, 2);
    expect(
      collections.memberships[SystemBookCollections.finished],
      contains('bobby'),
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('comic-reader-toolbar-visibility')),
          )
          .opacity,
      1,
    );
  });

  testWidgets('keeps the page while switching spreads and vertical mode', (
    tester,
  ) async {
    await _setWindow(tester, const Size(800, 1000));
    final preferences = _ComicReadingPreferencesRepository(
      const ComicReadingPreferences(doublePage: true),
    );
    await _pumpReader(
      tester,
      preferences: preferences,
      progress: _ReadingProgressRepository(
        ReadingProgress(
          publicationId: 'bobby',
          locator: ComicPageLocator(1),
          updatedAt: DateTime(2026),
        ),
      ),
    );
    expect(find.text('2–3 / 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Reading settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vertical scroll'));
    await tester.pumpAndSettle();
    final layout = tester.widget<SegmentedButton<bool>>(
      find.byKey(const Key('comic-reading-page-layout')),
    );
    expect(layout.onSelectionChanged, isNull);
    expect(preferences.preferences.mode, ComicReadingMode.vertical);
    expect(preferences.preferences.doublePage, isTrue);
    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsNothing);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Reading settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Right to left'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
    expect(find.text('2–3 / 3'), findsOneWidget);
    expect(tester.widget<PageView>(find.byType(PageView)).reverse, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows empty comics even when an old page has been saved', (
    tester,
  ) async {
    await _setWindow(tester, const Size(390, 844));
    await _pumpReader(
      tester,
      session: const _EmptyComicReaderSession(),
      progress: _ReadingProgressRepository(
        ReadingProgress(
          publicationId: 'bobby',
          locator: ComicPageLocator(10),
          updatedAt: DateTime(2026),
        ),
      ),
    );
    expect(
      find.text('This comic does not contain any readable image pages.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('comic-page-slider')), findsNothing);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a close action when the comic file is unavailable', (
    tester,
  ) async {
    await _setWindow(tester, const Size(390, 844));
    await _pumpReader(
      tester,
      openError: const FileSystemException('Missing comic'),
    );
    expect(find.text('File unavailable'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setWindow(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

IconButton _turnButton(WidgetTester tester, String key) =>
    tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(IconButton),
      ),
    );

Future<void> _pumpReader(
  WidgetTester tester, {
  ComicReaderSession session = const _ComicReaderSession(),
  Object? openError,
  _ComicReadingPreferencesRepository? preferences,
  _ArchiveEncodingRepository? encoding,
  _ReadingProgressRepository? progress,
  _BookCollectionRepository? collections,
}) async {
  const publication = Publication(
    id: 'bobby',
    source: LibrarySource(
      id: 'local-library',
      kind: LibrarySourceKind.local,
      name: 'Local library',
    ),
    title: 'Bobby Make-Believe',
    format: PublicationFormat.comicArchive,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        publicationRepositoryProvider.overrideWithValue(
          const _PublicationRepository(publication),
        ),
        comicReaderSessionFactoryProvider.overrideWithValue(
          _ComicReaderSessionFactory(session: session, openError: openError),
        ),
        comicReadingPreferencesRepositoryProvider.overrideWithValue(
          preferences ?? _ComicReadingPreferencesRepository(),
        ),
        comicArchiveFileNameEncodingRepositoryProvider.overrideWithValue(
          encoding ?? _ArchiveEncodingRepository(),
        ),
        readingProgressRepositoryProvider.overrideWithValue(
          progress ?? _ReadingProgressRepository(),
        ),
        bookCollectionRepositoryProvider.overrideWithValue(
          collections ?? _BookCollectionRepository(),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ComicReaderPage(
          publicationId: 'bobby',
          title: 'Bobby Make-Believe',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _PublicationRepository implements PublicationRepository {
  const _PublicationRepository(this.publication);

  final Publication publication;

  @override
  Future<void> delete(PublicationId id) async {}

  @override
  Future<Publication?> findByAssetLocation(Uri location) async => null;

  @override
  Future<Publication?> findById(PublicationId id) async =>
      id == publication.id ? publication : null;

  @override
  Future<List<Publication>> listPublications() async => [publication];

  @override
  Future<void> save(Publication publication) async {}

  @override
  Stream<List<Publication>> watchPublications() async* {
    yield [publication];
  }
}

class _ComicReaderSessionFactory implements ComicReaderSessionFactory {
  const _ComicReaderSessionFactory({
    this.session = const _ComicReaderSession(),
    this.openError,
  });

  final ComicReaderSession session;
  final Object? openError;

  @override
  Future<ComicReaderSession> open(Publication publication) async {
    if (openError != null) throw openError!;
    return session;
  }
}

class _ComicReaderSession implements ComicReaderSession {
  const _ComicReaderSession();

  @override
  ComicDocument get document => const ComicDocument(
    publicationId: 'bobby',
    pages: [
      ComicPageDescriptor(index: 0, name: '1.png'),
      ComicPageDescriptor(index: 1, name: '2.png'),
      ComicPageDescriptor(index: 2, name: '3.png'),
    ],
  );

  @override
  Future<Uint8List> readPage(int pageIndex) async => Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    0,
    0,
    0,
    13,
    73,
    72,
    68,
    82,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    1,
    8,
    6,
    0,
    0,
    0,
    31,
    21,
    196,
    137,
    0,
    0,
    0,
    13,
    73,
    68,
    65,
    84,
    8,
    215,
    99,
    248,
    207,
    192,
    240,
    31,
    0,
    5,
    0,
    1,
    255,
    137,
    153,
    61,
    29,
    0,
    0,
    0,
    0,
    73,
    69,
    78,
    68,
    174,
    66,
    96,
    130,
  ]);

  @override
  Future<void> close() async {}
}

class _ComicReadingPreferencesRepository
    implements ComicReadingPreferencesRepository {
  _ComicReadingPreferencesRepository([
    this.preferences = ComicReadingPreferences.defaults,
  ]);

  ComicReadingPreferences preferences;

  @override
  Future<ComicReadingPreferences> load() async => preferences;

  @override
  Future<void> save(ComicReadingPreferences preferences) async {
    this.preferences = preferences;
  }
}

class _ArchiveEncodingRepository
    implements ComicArchiveFileNameEncodingRepository {
  final values = <String, String>{};

  @override
  Future<void> delete(PublicationId publicationId) async {
    values.remove(publicationId);
  }

  @override
  Future<String?> load(PublicationId publicationId) async =>
      values[publicationId];

  @override
  Future<void> save(PublicationId publicationId, String? encodingName) async {
    if (encodingName == null) {
      values.remove(publicationId);
    } else {
      values[publicationId] = encodingName;
    }
  }
}

class _ReadingProgressRepository implements ReadingProgressRepository {
  _ReadingProgressRepository([this.progress]);

  ReadingProgress? progress;
  final saved = <ReadingProgress>[];

  @override
  Future<ReadingProgress?> load(PublicationId publicationId) async => progress;

  @override
  Future<void> save(ReadingProgress progress) async {
    this.progress = progress;
    saved.add(progress);
  }
}

class _CountingComicReaderSession extends _ComicReaderSession {
  var readCalls = 0;

  @override
  Future<Uint8List> readPage(int pageIndex) {
    readCalls++;
    return super.readPage(pageIndex);
  }
}

class _EmptyComicReaderSession extends _ComicReaderSession {
  const _EmptyComicReaderSession();

  @override
  ComicDocument get document =>
      const ComicDocument(publicationId: 'bobby', pages: []);
}

class _BookCollectionRepository implements BookCollectionRepository {
  final memberships = <String, Set<PublicationId>>{};

  @override
  Future<void> addPublication(
    String collectionId,
    PublicationId publicationId,
  ) async {
    memberships.putIfAbsent(collectionId, () => {}).add(publicationId);
  }

  @override
  Future<void> removePublication(
    String collectionId,
    PublicationId publicationId,
  ) async {
    memberships[collectionId]?.remove(publicationId);
  }

  @override
  Future<List<PublicationId>> listPublicationIds(String collectionId) async =>
      memberships[collectionId]?.toList() ?? [];
  @override
  Stream<List<PublicationId>> watchPublicationIds(String collectionId) async* {
    yield await listPublicationIds(collectionId);
  }

  @override
  Future<List<BookCollection>> listCollections() async => [];
  @override
  Future<BookCollection?> findById(String id) async => null;
  @override
  Future<void> save(BookCollection collection) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Stream<List<BookCollection>> watchCollections() async* {
    yield [];
  }
}
