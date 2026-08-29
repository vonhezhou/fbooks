import 'dart:typed_data';

import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/reader/comic_reader_session.dart';
import 'package:fbooks/domain/library/library_source.dart';
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
  testWidgets('uses a constrained stage and floating controls on desktop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final archiveEncodingRepository = _ArchiveEncodingRepository();

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
            _PublicationRepository(publication),
          ),
          comicReaderSessionFactoryProvider.overrideWithValue(
            const _ComicReaderSessionFactory(),
          ),
          comicReadingPreferencesRepositoryProvider.overrideWithValue(
            _ComicReadingPreferencesRepository(),
          ),
          comicArchiveFileNameEncodingRepositoryProvider.overrideWithValue(
            archiveEncodingRepository,
          ),
          readingProgressRepositoryProvider.overrideWithValue(
            const _ReadingProgressRepository(),
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

    expect(find.byKey(const Key('comic-reader-desktop-stage')), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byTooltip('Reading settings'), findsOneWidget);
    expect(tester.getSize(find.byType(Image).first).height, greaterThan(500));

    await tester.tap(find.byTooltip('Reading settings'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('comic-reader-desktop-settings')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopRight(find.byKey(const Key('comic-reader-desktop-settings')))
          .dx,
      1200,
    );
    final surface = tester.widget<Material>(
      find.byKey(const Key('comic-reading-settings-surface')),
    );
    expect(surface.color, const Color(0xFF202124));
    await tester.tap(
      find.byType(DropdownButtonFormField<ComicArchiveFileNameEncoding>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('GBK / GB18030').last);
    await tester.pumpAndSettle();
    expect(archiveEncodingRepository.values['bobby'], 'gbk');
    expect(tester.takeException(), isNull);
  });

  testWidgets('restores a saved comic page', (tester) async {
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
            _PublicationRepository(publication),
          ),
          comicReaderSessionFactoryProvider.overrideWithValue(
            const _ComicReaderSessionFactory(),
          ),
          comicReadingPreferencesRepositoryProvider.overrideWithValue(
            _ComicReadingPreferencesRepository(),
          ),
          readingProgressRepositoryProvider.overrideWithValue(
            _ReadingProgressRepository(
              ReadingProgress(
                publicationId: 'bobby',
                locator: ComicPageLocator(1),
                updatedAt: DateTime(2026),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ComicReaderPage(publicationId: 'bobby', title: 'Bobby'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('disables double-page spreads in vertical mode', (tester) async {
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
    final preferences = _ComicReadingPreferencesRepository(
      const ComicReadingPreferences(doublePage: true),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationRepositoryProvider.overrideWithValue(
            _PublicationRepository(publication),
          ),
          comicReaderSessionFactoryProvider.overrideWithValue(
            const _ComicReaderSessionFactory(),
          ),
          comicReadingPreferencesRepositoryProvider.overrideWithValue(
            preferences,
          ),
          readingProgressRepositoryProvider.overrideWithValue(
            const _ReadingProgressRepository(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ComicReaderPage(publicationId: 'bobby', title: 'Bobby'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reading settings'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.byKey(const Key('comic-reader-desktop-settings')),
      findsNothing,
    );
    await tester.tap(find.byType(DropdownMenu<ComicReadingMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vertical scroll').last);
    await tester.pumpAndSettle();

    final spreadToggle = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(spreadToggle.onChanged, isNull);
    expect(preferences.preferences.mode, ComicReadingMode.vertical);
  });
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
  const _ComicReaderSessionFactory();

  @override
  Future<ComicReaderSession> open(Publication publication) async =>
      const _ComicReaderSession();
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
  const _ReadingProgressRepository([this.progress]);

  final ReadingProgress? progress;

  @override
  Future<ReadingProgress?> load(PublicationId publicationId) async => progress;

  @override
  Future<void> save(ReadingProgress progress) async {}
}
