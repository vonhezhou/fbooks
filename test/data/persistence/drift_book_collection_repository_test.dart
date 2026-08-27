import 'package:drift/native.dart';
import 'package:fbooks/data/persistence/drift_book_collection_repository.dart';
import 'package:fbooks/data/persistence/drift_publication_repository.dart';
import 'package:fbooks/data/persistence/local_database.dart';
import 'package:fbooks/domain/collection/book_collection.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalDatabase database;
  late DriftBookCollectionRepository repository;

  setUp(() {
    database = LocalDatabase.forTesting(NativeDatabase.memory());
    repository = DriftBookCollectionRepository(database);
  });

  tearDown(() => database.close());

  test('persists a custom collection and its publication membership', () async {
    const publication = Publication(
      id: 'book-1',
      source: LibrarySource(
        id: 'local-library',
        kind: LibrarySourceKind.local,
        name: 'Local library',
      ),
      title: 'A local book',
      format: PublicationFormat.epub,
    );
    await DriftPublicationRepository(database).save(publication);
    final collection = BookCollection(
      id: 'collection-1',
      name: 'Summer reading',
      description: 'Books for the holiday.',
      kind: BookCollectionKind.custom,
      createdAt: DateTime(2026, 8, 27),
      updatedAt: DateTime(2026, 8, 27),
    );

    await repository.save(collection);
    await repository.addPublication(collection.id, publication.id);

    final collections = await repository.listCollections();
    expect(collections, hasLength(1));
    expect(collections.single.name, collection.name);
    expect(collections.single.description, collection.description);
    expect(await repository.listPublicationIds(collection.id), [
      publication.id,
    ]);
  });

  test('creates a built-in collection when a book is added to it', () async {
    const publication = Publication(
      id: 'book-2',
      source: LibrarySource(
        id: 'local-library',
        kind: LibrarySourceKind.local,
        name: 'Local library',
      ),
      title: 'A comic',
      format: PublicationFormat.comicArchive,
    );
    await DriftPublicationRepository(database).save(publication);

    await repository.addPublication(
      SystemBookCollections.favorites,
      publication.id,
    );

    expect(
      await repository.listPublicationIds(SystemBookCollections.favorites),
      [publication.id],
    );
    expect(
      (await repository.findById(SystemBookCollections.favorites))?.kind,
      BookCollectionKind.system,
    );
  });
}
