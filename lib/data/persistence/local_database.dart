import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_database.g.dart';

class StoredLibrarySources extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get name => text()();
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

@DriftDatabase(
  tables: [
    StoredLibrarySources,
    StoredPublications,
    StoredReadingProgresses,
    StoredPublicationAssets,
  ],
)
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(driftDatabase(name: 'fbooks'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      switch (from) {
        case 1:
          await migrator.createTable(storedPublicationAssets);
          break;
        case 2:
          break;
        default:
          throw StateError('Unsupported database migration: $from -> $to.');
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
