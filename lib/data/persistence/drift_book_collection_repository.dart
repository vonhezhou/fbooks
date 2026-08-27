import 'package:drift/drift.dart';
import 'package:fbooks/data/persistence/local_database.dart';
import 'package:fbooks/domain/collection/book_collection.dart';
import 'package:fbooks/domain/collection/book_collection_repository.dart';
import 'package:fbooks/domain/publication/publication_id.dart';

class DriftBookCollectionRepository implements BookCollectionRepository {
  DriftBookCollectionRepository(this._database);

  final LocalDatabase _database;

  @override
  Future<void> addPublication(
    String collectionId,
    PublicationId publicationId,
  ) async {
    await _database.transaction(() async {
      await _ensureSystemCollection(collectionId);
      await _database
          .into(_database.storedCollectionPublications)
          .insertOnConflictUpdate(
            StoredCollectionPublicationsCompanion.insert(
              collectionId: collectionId,
              publicationId: publicationId,
              createdAt: DateTime.now(),
            ),
          );
    });
  }

  @override
  Future<void> delete(String id) async {
    if (SystemBookCollections.all.any((collection) => collection.id == id)) {
      throw ArgumentError.value(
        id,
        'id',
        'System collections cannot be deleted',
      );
    }
    await (_database.delete(
      _database.storedBookCollections,
    )..where((collection) => collection.id.equals(id))).go();
  }

  @override
  Future<BookCollection?> findById(String id) async {
    final row = await (_database.select(
      _database.storedBookCollections,
    )..where((collection) => collection.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<BookCollection>> listCollections() async {
    final rows =
        await (_database.select(_database.storedBookCollections)
              ..where((row) => row.kind.equals(BookCollectionKind.custom.name))
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<List<PublicationId>> listPublicationIds(String collectionId) async {
    final rows =
        await (_database.select(_database.storedCollectionPublications)
              ..where((entry) => entry.collectionId.equals(collectionId))
              ..orderBy([(entry) => OrderingTerm.asc(entry.createdAt)]))
            .get();
    return rows.map((row) => row.publicationId).toList(growable: false);
  }

  @override
  Future<void> removePublication(
    String collectionId,
    PublicationId publicationId,
  ) async {
    await (_database.delete(_database.storedCollectionPublications)
          ..where((entry) => entry.collectionId.equals(collectionId))
          ..where((entry) => entry.publicationId.equals(publicationId)))
        .go();
  }

  @override
  Future<void> save(BookCollection collection) async {
    await _database
        .into(_database.storedBookCollections)
        .insertOnConflictUpdate(
          StoredBookCollectionsCompanion.insert(
            id: collection.id,
            name: collection.name,
            kind: collection.kind.name,
            description: Value(collection.description),
            coverUri: Value(collection.coverUri?.toString()),
            createdAt: collection.createdAt,
            updatedAt: collection.updatedAt,
          ),
        );
  }

  @override
  Stream<List<BookCollection>> watchCollections() {
    return (_database.select(_database.storedBookCollections)
          ..where((row) => row.kind.equals(BookCollectionKind.custom.name))
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Stream<List<PublicationId>> watchPublicationIds(String collectionId) {
    return (_database.select(_database.storedCollectionPublications)
          ..where((entry) => entry.collectionId.equals(collectionId))
          ..orderBy([(entry) => OrderingTerm.asc(entry.createdAt)]))
        .watch()
        .map(
          (rows) =>
              rows.map((row) => row.publicationId).toList(growable: false),
        );
  }

  BookCollection _toDomain(StoredBookCollection row) => BookCollection(
    id: row.id,
    name: row.name,
    kind: BookCollectionKind.values.byName(row.kind),
    description: row.description,
    coverUri: row.coverUri == null ? null : Uri.parse(row.coverUri!),
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  Future<void> _ensureSystemCollection(String collectionId) async {
    final collection = SystemBookCollections.all
        .where((item) => item.id == collectionId)
        .firstOrNull;
    if (collection == null) {
      return;
    }
    await _database
        .into(_database.storedBookCollections)
        .insert(
          StoredBookCollectionsCompanion.insert(
            id: collection.id,
            name: collection.name,
            kind: collection.kind.name,
            createdAt: collection.createdAt,
            updatedAt: collection.updatedAt,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
}
