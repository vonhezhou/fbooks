import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_database.g.dart';

class StoredLibrarySources extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  TextColumn get endpoint => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StoredPublications extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId => text().references(StoredLibrarySources, #id)();
  TextColumn get title => text()();
  TextColumn get authorsJson => text().withDefault(const Constant('[]'))();
  TextColumn get format => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverUri => text().nullable()();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StoredReadingProgresses extends Table {
  TextColumn get publicationId => text().references(StoredPublications, #id)();
  TextColumn get locatorType => text()();
  TextColumn get locatorValue => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {publicationId};
}

class StoredPublicationAssets extends Table {
  TextColumn get id => text()();
  TextColumn get publicationId => text().references(StoredPublications, #id)();
  TextColumn get kind => text()();
  TextColumn get location => text()();
  TextColumn get mediaType => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StoredBookCollections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverUri => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StoredCollectionPublications extends Table {
  TextColumn get collectionId =>
      text().references(StoredBookCollections, #id)();
  TextColumn get publicationId => text().references(StoredPublications, #id)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {collectionId, publicationId};
}

@DriftDatabase(
  tables: [
    StoredLibrarySources,
    StoredPublications,
    StoredReadingProgresses,
    StoredPublicationAssets,
    StoredBookCollections,
    StoredCollectionPublications,
  ],
)
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(driftDatabase(name: 'fbooks'));

  LocalDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 1 || from > 6) {
        throw StateError('Unsupported database migration: $from -> $to.');
      }
      if (from == 1) {
        await migrator.createTable(storedPublicationAssets);
      }
      if (from <= 2) {
        await migrator.addColumn(
          storedLibrarySources,
          storedLibrarySources.endpoint,
        );
      }
      if (from <= 3) {
        await migrator.createTable(storedBookCollections);
        await migrator.createTable(storedCollectionPublications);
      }
      if (from <= 4) {
        await customStatement(
          "DELETE FROM stored_collection_publications WHERE collection_id = 'system:saved'",
        );
        await customStatement(
          "DELETE FROM stored_book_collections WHERE id = 'system:saved'",
        );
      }
      if (from <= 5) {
        await migrator.addColumn(
          storedPublications,
          storedPublications.publishedAt,
        );
        await migrator.addColumn(
          storedPublications,
          storedPublications.tagsJson,
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
