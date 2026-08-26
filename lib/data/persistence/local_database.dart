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

@DriftDatabase(
  tables: [StoredLibrarySources, StoredPublications, StoredReadingProgresses],
)
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(driftDatabase(name: 'fbooks'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from != to) {
        throw StateError(
          'A database migration must be written for $from -> $to.',
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
