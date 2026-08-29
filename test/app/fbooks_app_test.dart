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
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Fbooks'), findsOneWidget);
    expect(find.text('Your library will appear here.'), findsOneWidget);
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
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Your library'), findsOneWidget);
    expect(find.text('Collections'), findsOneWidget);
    expect(find.text('Add books'), findsOneWidget);
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
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Bobby Make-Believe'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

class _FixedAppSettingsRepository implements AppSettingsRepository {
  const _FixedAppSettingsRepository(this.settings);

  final AppSettings settings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async {}
}
