import 'package:fbooks/app/providers.dart';
import 'package:fbooks/domain/collection/book_collection.dart';
import 'package:fbooks/domain/collection/book_collection_repository.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:fbooks/features/collections/presentation/collections_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('adapts the collection hero to desktop and compact windows', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 840);
    await tester.binding.setSurfaceSize(const Size(1280, 840));
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
    });
    final collection = BookCollection(
      id: 'weekend-reads',
      name: 'Weekend reads',
      kind: BookCollectionKind.custom,
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
            const _PublicationRepository([book]),
          ),
          bookCollectionRepositoryProvider.overrideWithValue(
            const _BookCollectionRepository({
              'weekend-reads': ['bobby'],
            }),
          ),
        ],
        child: MaterialApp(
          home: BookCollectionDetailPage(collection: collection),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('collection-detail-desktop-content')),
      findsOneWidget,
    );
    expect(find.text('Bobby Make-Believe'), findsOneWidget);
    expect(find.text('Start reading'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final width in [800.0, 390.0]) {
      tester.view.physicalSize = Size(width, 840);
      await tester.binding.setSurfaceSize(Size(width, 840));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('collection-detail-desktop-content')),
        findsNothing,
      );
      expect(find.text('Start reading'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

class _PublicationRepository implements PublicationRepository {
  const _PublicationRepository(this.publications);

  final List<Publication> publications;

  @override
  Future<void> delete(PublicationId id) async {}

  @override
  Future<Publication?> findByAssetLocation(Uri location) async => null;

  @override
  Future<Publication?> findById(PublicationId id) async =>
      publications.where((publication) => publication.id == id).firstOrNull;

  @override
  Future<List<Publication>> listPublications() async => publications;

  @override
  Future<void> save(Publication publication) async {}

  @override
  Stream<List<Publication>> watchPublications() async* {
    yield publications;
  }
}

class _BookCollectionRepository implements BookCollectionRepository {
  const _BookCollectionRepository(this.memberships);

  final Map<String, List<PublicationId>> memberships;

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
      memberships[collectionId] ?? const [];

  @override
  Future<void> removePublication(
    String collectionId,
    PublicationId publicationId,
  ) async {}

  @override
  Future<void> save(BookCollection collection) async {}

  @override
  Stream<List<BookCollection>> watchCollections() async* {
    yield const [];
  }

  @override
  Stream<List<PublicationId>> watchPublicationIds(String collectionId) async* {
    yield memberships[collectionId] ?? const [];
  }
}
