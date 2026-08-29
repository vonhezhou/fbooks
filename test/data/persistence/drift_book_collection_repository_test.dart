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

  void openDatabase() {
    database = LocalDatabase.forTesting(NativeDatabase.memory());
    repository = DriftBookCollectionRepository(database);
    addTearDown(database.close);
  }

  test('persists a custom collection and its publication membership', () async {
    openDatabase();
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
    openDatabase();
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

  test('exposes the three non-overlapping system collections', () {
    expect(SystemBookCollections.all.map((collection) => collection.id), [
      SystemBookCollections.readLater,
      SystemBookCollections.favorites,
      SystemBookCollections.finished,
    ]);
    expect(SystemBookCollections.all.map((collection) => collection.name), [
      'Read later',
      'Favorites',
      'Finished',
    ]);
  });

  test('removes the retired Saved system collection during v4 migration', () async {
    final migratedDatabase = LocalDatabase.forTesting(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          rawDatabase
            ..execute('''
              CREATE TABLE stored_book_collections (
                id TEXT NOT NULL PRIMARY KEY,
                name TEXT NOT NULL,
                kind TEXT NOT NULL,
                description TEXT,
                cover_uri TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              )
            ''')
            ..execute('''
              CREATE TABLE stored_collection_publications (
                collection_id TEXT NOT NULL,
                publication_id TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                PRIMARY KEY (collection_id, publication_id)
              )
            ''')
            ..execute("""
              INSERT INTO stored_book_collections
                (id, name, kind, created_at, updated_at)
              VALUES ('system:saved', 'Saved', 'system', 0, 0)
            """)
            ..execute("""
              INSERT INTO stored_book_collections
                (id, name, kind, created_at, updated_at)
              VALUES ('system:favorites', 'Favorites', 'system', 0, 0)
            """)
            ..execute("""
              INSERT INTO stored_collection_publications
                (collection_id, publication_id, created_at)
              VALUES ('system:saved', 'book-1', 0)
            """)
            ..execute('PRAGMA user_version = 4');
        },
      ),
    );
    addTearDown(migratedDatabase.close);

    expect(
      await migratedDatabase
          .customSelect(
            "SELECT id FROM stored_book_collections WHERE id = 'system:saved'",
          )
          .get(),
      isEmpty,
    );
    expect(
      await migratedDatabase
          .customSelect(
            "SELECT collection_id FROM stored_collection_publications WHERE collection_id = 'system:saved'",
          )
          .get(),
      isEmpty,
    );
    expect(
      await migratedDatabase
          .customSelect(
            "SELECT id FROM stored_book_collections WHERE id = 'system:favorites'",
          )
          .get(),
      hasLength(1),
    );
  });
}
