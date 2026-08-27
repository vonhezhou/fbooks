import 'package:fbooks/app/providers.dart';
import 'package:fbooks/app/fbooks_app.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/reading_progress_repository.dart';
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
