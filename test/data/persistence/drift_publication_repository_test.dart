import 'package:drift/native.dart';
import 'package:fbooks/data/persistence/drift_book_collection_repository.dart';
import 'package:fbooks/data/persistence/drift_publication_repository.dart';
import 'package:fbooks/data/persistence/drift_reading_progress_repository.dart';
import 'package:fbooks/data/persistence/local_database.dart';
import 'package:fbooks/domain/collection/book_collection.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalDatabase database;
  late DriftPublicationRepository publicationRepository;

  setUp(() {
    database = LocalDatabase.forTesting(NativeDatabase.memory());
    publicationRepository = DriftPublicationRepository(database);
  });

  tearDown(() => database.close());

  test(
    'deletes a publication with its progress, assets, and memberships',
    () async {
      final publication = Publication(
        id: 'book-1',
        source: LibrarySource(
          id: 'local-library',
          kind: LibrarySourceKind.local,
          name: 'Local library',
        ),
        title: 'A local book',
        format: PublicationFormat.epub,
        assets: [
          PublicationAsset(
            id: 'book-1-file',
            publicationId: 'book-1',
            kind: PublicationAssetKind.localFile,
            location: Uri(scheme: 'file', path: '/books/book-1.epub'),
          ),
        ],
      );
      await publicationRepository.save(publication);
      final progressRepository = DriftReadingProgressRepository(database);
      final collectionRepository = DriftBookCollectionRepository(database);
      await progressRepository.save(
        ReadingProgress(
          publicationId: publication.id,
          locator: const TextOffsetLocator(chapterIndex: 1, offset: 10),
          updatedAt: DateTime(2026, 8, 27),
        ),
      );
      await collectionRepository.addPublication(
        SystemBookCollections.favorites,
        publication.id,
      );

      await publicationRepository.delete(publication.id);

      expect(await publicationRepository.findById(publication.id), isNull);
      expect(await progressRepository.load(publication.id), isNull);
      expect(
        await collectionRepository.listPublicationIds(
          SystemBookCollections.favorites,
        ),
        isEmpty,
      );
      expect(
        await database.select(database.storedPublicationAssets).get(),
        isEmpty,
      );
    },
  );

  test('persists publication date and tags', () async {
    final publication = Publication(
      id: 'metadata-book',
      source: LibrarySource(
        id: 'local-library',
        kind: LibrarySourceKind.local,
        name: 'Local library',
      ),
      title: 'Metadata book',
      format: PublicationFormat.epub,
      publishedAt: DateTime(2024, 5, 6),
      tags: const ['Fiction', 'Gardens'],
    );

    await publicationRepository.save(publication);

    final reloaded = await publicationRepository.findById(publication.id);
    expect(reloaded?.publishedAt, DateTime(2024, 5, 6));
    expect(reloaded?.tags, ['Fiction', 'Gardens']);
  });
}
