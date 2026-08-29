import 'package:fbooks/app/providers.dart';
import 'package:fbooks/app/fbooks_app.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/collection/book_collection.dart';
import 'package:fbooks/domain/collection/book_collection_repository.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/reading_progress_repository.dart';
import 'package:fbooks/domain/settings/app_settings.dart';
import 'package:fbooks/domain/settings/app_settings_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('shows the empty library landing page', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationRepositoryProvider.overrideWithValue(
            _EmptyPublicationRepository(),
          ),
          bookCollectionRepositoryProvider.overrideWithValue(
            _EmptyBookCollectionRepository(),
          ),
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pump();

    expect(find.text('fBooks'), findsOneWidget);
    expect(find.text('Your library will appear here.'), findsOneWidget);
  });

  testWidgets('uses the persisted Chinese locale for app navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationRepositoryProvider.overrideWithValue(
            _EmptyPublicationRepository(),
          ),
          bookCollectionRepositoryProvider.overrideWithValue(
            _EmptyBookCollectionRepository(),
          ),
          appSettingsRepositoryProvider.overrideWithValue(
            _FixedAppSettingsRepository(
              const AppSettings(locale: Locale('zh')),
            ),
          ),
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('书库'), findsOneWidget);
    expect(find.text('你的书库将在这里显示。'), findsOneWidget);
  });

  testWidgets('uses the desktop library shell in a wide window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationRepositoryProvider.overrideWithValue(
            _EmptyPublicationRepository(),
          ),
          bookCollectionRepositoryProvider.overrideWithValue(
            _EmptyBookCollectionRepository(),
          ),
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Your library'), findsOneWidget);
    expect(find.text('fBooks'), findsOneWidget);
    expect(find.byKey(const Key('brand-logo')), findsOneWidget);
    expect(find.text('Collections'), findsOneWidget);
    expect(find.text('Add books'), findsOneWidget);
  });

  testWidgets('switches between desktop and compact library layouts', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
    });
    try {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            publicationRepositoryProvider.overrideWithValue(
              _EmptyPublicationRepository(),
            ),
            bookCollectionRepositoryProvider.overrideWithValue(
              _EmptyBookCollectionRepository(),
            ),
          ],
          child: const FbooksApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.binding.setSurfaceSize(const Size(800, 800));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('window-close')), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('shows the local diagnostics directory in settings', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationRepositoryProvider.overrideWithValue(
            _EmptyPublicationRepository(),
          ),
          bookCollectionRepositoryProvider.overrideWithValue(
            _EmptyBookCollectionRepository(),
          ),
          appLogDirectoryProvider.overrideWithValue('/diagnostics/fbooks/logs'),
          appSettingsRepositoryProvider.overrideWithValue(
            _FixedAppSettingsRepository(
              const AppSettings(themeMode: ThemeMode.system),
            ),
          ),
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();

    expect(find.text('Log directory'), findsOneWidget);
    expect(find.text('Log level'), findsOneWidget);
    expect(
      find.text('Tap to copy the path for local diagnostics.'),
      findsOneWidget,
    );
  });

  testWidgets('uses a dark surface for every desktop primary page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationRepositoryProvider.overrideWithValue(
            _EmptyPublicationRepository(),
          ),
          bookCollectionRepositoryProvider.overrideWithValue(
            _EmptyBookCollectionRepository(),
          ),
          appSettingsRepositoryProvider.overrideWithValue(
            _FixedAppSettingsRepository(
              const AppSettings(themeMode: ThemeMode.dark),
            ),
          ),
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pumpAndSettle();

    final primarySurface = tester.widget<Material>(
      find.byKey(const Key('primary-content-surface')),
    );
    expect(primarySurface.color, const Color(0xFF1C1D20));
    _expectDarkTheme(tester, find.text('Your library'));

    await tester.tap(find.text('Collections').first);
    await tester.pumpAndSettle();
    _expectDarkTheme(tester, find.text('Collections').last);

    await tester.tap(find.text('Plugins').first);
    await tester.pumpAndSettle();
    _expectDarkTheme(tester, find.text('Plugins').last);

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    _expectDarkTheme(tester, find.text('Settings').last);
  });

  testWidgets('expands desktop collections and shows a selected list inline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final collection = BookCollection(
      id: 'weekend-reads',
      name: 'Weekend reads',
      kind: BookCollectionKind.custom,
      description: 'Books for the weekend.',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    const book = Publication(
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
            _FixedPublicationRepository(const [book]),
          ),
          bookCollectionRepositoryProvider.overrideWithValue(
            _FixedBookCollectionRepository(
              collections: [collection],
              memberships: const {
                'weekend-reads': ['bobby'],
              },
            ),
          ),
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pumpAndSettle();

    final collectionItem = find.byKey(
      const Key('sidebar-collection-weekend-reads'),
    );
    expect(collectionItem, findsOneWidget);
    expect(find.byTooltip('Collapse collections'), findsOneWidget);

    await tester.tap(collectionItem);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-collection-detail')), findsOneWidget);
    expect(find.text('Bobby Make-Believe'), findsOneWidget);
    expect(find.byTooltip('Manage books'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse collections'));
    await tester.pumpAndSettle();

    expect(collectionItem, findsNothing);
    expect(find.byTooltip('Expand collections'), findsOneWidget);
  });

  testWidgets('renders an imported book in a medium desktop window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationRepositoryProvider.overrideWithValue(
            _FixedPublicationRepository(const [
              Publication(
                id: 'local-comic',
                source: LibrarySource(
                  id: 'local-library',
                  kind: LibrarySourceKind.local,
                  name: 'Local library',
                ),
                title: 'Bobby Make-Believe',
                format: PublicationFormat.comicArchive,
              ),
            ]),
          ),
          readingProgressRepositoryProvider.overrideWithValue(
            _EmptyReadingProgressRepository(),
          ),
          bookCollectionRepositoryProvider.overrideWithValue(
            _EmptyBookCollectionRepository(),
          ),
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Bobby Make-Believe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press selects a book and enters selection mode', (
    tester,
  ) async {
    const book = Publication(
      id: 'gesture-book',
      source: LibrarySource(
        id: 'local-library',
        kind: LibrarySourceKind.local,
        name: 'Local library',
      ),
      title: 'Gesture Book',
      format: PublicationFormat.epub,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationRepositoryProvider.overrideWithValue(
            _FixedPublicationRepository(const [book]),
          ),
          readingProgressRepositoryProvider.overrideWithValue(
            _EmptyReadingProgressRepository(),
          ),
          bookCollectionRepositoryProvider.overrideWithValue(
            _EmptyBookCollectionRepository(),
          ),
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const Key('publication-card-gesture-book')),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('secondary click opens the single-book action menu', (
    tester,
  ) async {
    const book = Publication(
      id: 'context-book',
      source: LibrarySource(
        id: 'local-library',
        kind: LibrarySourceKind.local,
        name: 'Local library',
      ),
      title: 'Context Book',
      format: PublicationFormat.epub,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationRepositoryProvider.overrideWithValue(
            _FixedPublicationRepository(const [book]),
          ),
          readingProgressRepositoryProvider.overrideWithValue(
            _EmptyReadingProgressRepository(),
          ),
          bookCollectionRepositoryProvider.overrideWithValue(
            _EmptyBookCollectionRepository(),
          ),
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('publication-card-context-book'))),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(find.text('Open / continue reading'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
  });

  testWidgets('aligns desktop library content and keeps details compact', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationRepositoryProvider.overrideWithValue(
            _FixedPublicationRepository(const [
              Publication(
                id: 'aligned-book',
                source: LibrarySource(
                  id: 'local-library',
                  kind: LibrarySourceKind.local,
                  name: 'Local library',
                ),
                title: 'Aligned book',
                format: PublicationFormat.epub,
              ),
            ]),
          ),
          readingProgressRepositoryProvider.overrideWithValue(
            _EmptyReadingProgressRepository(),
          ),
          bookCollectionRepositoryProvider.overrideWithValue(
            _EmptyBookCollectionRepository(),
          ),
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const Key('desktop-library-header'))).dx,
      tester.getTopLeft(find.byKey(const Key('library-filter-controls'))).dx,
    );
    expect(
      tester
          .getTopLeft(find.byKey(const Key('publication-card-aligned-book')))
          .dx,
      tester.getTopLeft(find.byKey(const Key('library-publication-grid'))).dx,
    );
    expect(
      tester.getSize(find.byKey(const Key('publication-details-aligned-book'))),
      const Size(32, 32),
    );
  });

  testWidgets('shows the not-found page for an unknown named route', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationRepositoryProvider.overrideWithValue(
            _EmptyPublicationRepository(),
          ),
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pump();

    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/missing');
    await tester.pumpAndSettle();

    expect(find.text('This page is not in your library.'), findsOneWidget);
    expect(find.textContaining('“/missing”'), findsOneWidget);
  });

  testWidgets('searches library titles and authors', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationRepositoryProvider.overrideWithValue(
            _FixedPublicationRepository(const [
              Publication(
                id: 'local-book',
                source: LibrarySource(
                  id: 'local-library',
                  kind: LibrarySourceKind.local,
                  name: 'Local library',
                ),
                title: 'The Garden',
                authors: ['Ada'],
                format: PublicationFormat.epub,
              ),
              Publication(
                id: 'remote-book',
                source: LibrarySource(
                  id: 'opds:https://books.example.org',
                  kind: LibrarySourceKind.opds,
                  name: 'Example catalog',
                ),
                title: 'Ocean Stories',
                authors: ['Grace'],
                format: PublicationFormat.text,
              ),
            ]),
          ),
          readingProgressRepositoryProvider.overrideWithValue(
            _EmptyReadingProgressRepository(),
          ),
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pump();

    expect(find.text('The Garden'), findsOneWidget);
    expect(find.text('Ocean Stories'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'grace');
    await tester.pump();

    expect(find.text('The Garden'), findsNothing);
    expect(find.text('Ocean Stories'), findsOneWidget);
  });
}

void _expectDarkTheme(WidgetTester tester, Finder finder) {
  expect(
    Theme.of(tester.element(finder)).colorScheme.brightness,
    Brightness.dark,
  );
}

class _EmptyPublicationRepository implements PublicationRepository {
  @override
  Future<void> delete(PublicationId id) => throw UnimplementedError();

  @override
  Future<Publication?> findById(PublicationId id) => throw UnimplementedError();

  @override
  Future<Publication?> findByAssetLocation(Uri location) =>
      throw UnimplementedError();

  @override
  Future<List<Publication>> listPublications() => Future.value(const []);

  @override
  Future<void> save(Publication publication) => throw UnimplementedError();

  @override
  Stream<List<Publication>> watchPublications() => Stream.value(const []);
}

class _FixedPublicationRepository implements PublicationRepository {
  _FixedPublicationRepository(this.publications);

  final List<Publication> publications;

  @override
  Future<void> delete(PublicationId id) => throw UnimplementedError();

  @override
  Future<Publication?> findById(PublicationId id) async =>
      publications.where((publication) => publication.id == id).firstOrNull;

  @override
  Future<Publication?> findByAssetLocation(Uri location) =>
      throw UnimplementedError();

  @override
  Future<List<Publication>> listPublications() async => publications;

  @override
  Future<void> save(Publication publication) => throw UnimplementedError();

  @override
  Stream<List<Publication>> watchPublications() => Stream.value(publications);
}

class _EmptyReadingProgressRepository implements ReadingProgressRepository {
  @override
  Future<ReadingProgress?> load(PublicationId publicationId) async => null;

  @override
  Future<void> save(ReadingProgress progress) async {}
}

class _EmptyBookCollectionRepository implements BookCollectionRepository {
  @override
  Future<void> addPublication(
    String collectionId,
    PublicationId publicationId,
  ) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<BookCollection?> findById(String id) async => null;

  @override
  Future<List<BookCollection>> listCollections() async => const [];

  @override
  Future<List<PublicationId>> listPublicationIds(String collectionId) async =>
      const [];

  @override
  Future<void> removePublication(
    String collectionId,
    PublicationId publicationId,
  ) async {}

  @override
  Future<void> save(BookCollection collection) async {}

  @override
  Stream<List<BookCollection>> watchCollections() => Stream.value(const []);

  @override
  Stream<List<PublicationId>> watchPublicationIds(String collectionId) =>
      Stream.value(const []);
}

class _FixedBookCollectionRepository implements BookCollectionRepository {
  const _FixedBookCollectionRepository({
    required this.collections,
    required this.memberships,
  });

  final List<BookCollection> collections;
  final Map<String, List<PublicationId>> memberships;

  @override
  Future<void> addPublication(
    String collectionId,
    PublicationId publicationId,
  ) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<BookCollection?> findById(String id) async =>
      collections.where((collection) => collection.id == id).firstOrNull;

  @override
  Future<List<BookCollection>> listCollections() async => collections;

  @override
  Future<List<PublicationId>> listPublicationIds(String collectionId) async =>
      memberships[collectionId] ?? const [];

  @override
  Future<void> removePublication(
    String collectionId,
    PublicationId publicationId,
  ) async {}

  @override
  Future<void> save(BookCollection collection) async {}

  @override
  Stream<List<BookCollection>> watchCollections() => Stream.value(collections);

  @override
  Stream<List<PublicationId>> watchPublicationIds(String collectionId) =>
      Stream.value(memberships[collectionId] ?? const []);
}

class _FixedAppSettingsRepository implements AppSettingsRepository {
  const _FixedAppSettingsRepository(this.settings);

  final AppSettings settings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async {}
}
