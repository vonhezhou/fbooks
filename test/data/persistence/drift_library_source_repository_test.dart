import 'package:drift/native.dart';
import 'package:fbooks/data/persistence/drift_library_source_repository.dart';
import 'package:fbooks/data/persistence/local_database.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists an OPDS source endpoint', () async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftLibrarySourceRepository(database);
    final source = LibrarySource(
      id: 'opds:example',
      kind: LibrarySourceKind.opds,
      name: 'Example catalog',
      endpoint: Uri.parse('https://books.example.org/opds'),
    );

    await repository.save(source);
    final sources = await repository.listSources();

    expect(sources, hasLength(1));
    expect(sources.single.endpoint, source.endpoint);
  });
}
