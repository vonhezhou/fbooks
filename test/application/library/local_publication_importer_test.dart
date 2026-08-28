import 'package:fbooks/application/library/local_publication_importer.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'imports a supported local publication with a local-file asset',
    () async {
      final repository = _MemoryPublicationRepository();
      final importer = LocalPublicationImporter(repository);

      final result = await importer.importCandidates([
        LocalPublicationCandidate(
          fileName: 'The Sandman.cbz',
          location: Uri.file('/books/The Sandman.cbz'),
        ),
      ]);

      expect(result.imported, hasLength(1));
      expect(result.duplicates, isEmpty);
      expect(result.unsupported, isEmpty);
      expect(result.imported.single.title, 'The Sandman');
      expect(
        result.imported.single.assets.single.location.toFilePath(),
        '/books/The Sandman.cbz',
      );
      expect(await repository.listPublications(), hasLength(1));
    },
  );

  test('does not import the same local file twice', () async {
    final repository = _MemoryPublicationRepository();
    final importer = LocalPublicationImporter(repository);
    final candidate = LocalPublicationCandidate(
      fileName: 'Book.epub',
      location: Uri.file('/books/Book.epub'),
    );

    await importer.importCandidates([candidate]);
    final result = await importer.importCandidates([candidate]);

    expect(result.imported, isEmpty);
    expect(result.duplicates, [candidate]);
    expect(await repository.listPublications(), hasLength(1));
  });

  test(
    'reports unsupported file extensions without writing metadata',
    () async {
      final repository = _MemoryPublicationRepository();
      final importer = LocalPublicationImporter(repository);
      final candidate = LocalPublicationCandidate(
        fileName: 'notes.docx',
        location: Uri.file('/books/notes.docx'),
      );

      final result = await importer.importCandidates([candidate]);

      expect(result.imported, isEmpty);
      expect(result.unsupported, [candidate]);
      expect(await repository.listPublications(), isEmpty);
    },
  );

  test('only accepts local formats the reader can open', () async {
    final repository = _MemoryPublicationRepository();
    final importer = LocalPublicationImporter(repository);
    final candidates =
        ['Comic.cbz', 'Book.epub', 'Notes.txt', 'Comic.cbr', 'Book.pdf'].map(
          (name) => LocalPublicationCandidate(
            fileName: name,
            location: Uri.file('/books/$name'),
          ),
        );

    final result = await importer.importCandidates(candidates.toList());

    expect(result.imported, hasLength(4));
    expect(result.unsupported.map((candidate) => candidate.fileName), [
      'Comic.cbr',
    ]);
  });
}

class _MemoryPublicationRepository implements PublicationRepository {
  final Map<PublicationId, Publication> _publications = {};

  @override
  Future<void> delete(PublicationId id) async {
    _publications.remove(id);
  }

  @override
  Future<Publication?> findByAssetLocation(Uri location) async {
    for (final publication in _publications.values) {
      if (publication.assets.any((asset) => asset.location == location)) {
        return publication;
      }
    }
    return null;
  }

  @override
  Future<Publication?> findById(PublicationId id) async => _publications[id];

  @override
  Future<List<Publication>> listPublications() async =>
      _publications.values.toList();

  @override
  Future<void> save(Publication publication) async {
    _publications[publication.id] = publication;
  }

  @override
  Stream<List<Publication>> watchPublications() async* {
    yield _publications.values.toList();
  }
}
