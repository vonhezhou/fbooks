import 'package:drift/drift.dart';
import 'package:fbooks/data/persistence/local_database.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/library/library_source_repository.dart';

class DriftLibrarySourceRepository implements LibrarySourceRepository {
  DriftLibrarySourceRepository(this._database);

  final LocalDatabase _database;

  @override
  Future<void> delete(String sourceId) async {
    await (_database.delete(
      _database.storedLibrarySources,
    )..where((source) => source.id.equals(sourceId))).go();
  }

  @override
  Future<List<LibrarySource>> listSources() async {
    final rows = await _database.select(_database.storedLibrarySources).get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<void> save(LibrarySource source) async {
    await _database
        .into(_database.storedLibrarySources)
        .insertOnConflictUpdate(
          StoredLibrarySourcesCompanion.insert(
            id: source.id,
            kind: source.kind.name,
            name: source.name,
            endpoint: Value(source.endpoint?.toString()),
            createdAt: DateTime.now(),
          ),
        );
  }

  LibrarySource _toDomain(StoredLibrarySource source) {
    return LibrarySource(
      id: source.id,
      kind: LibrarySourceKind.values.byName(source.kind),
      name: source.name,
      endpoint: source.endpoint == null ? null : Uri.parse(source.endpoint!),
    );
  }
}
