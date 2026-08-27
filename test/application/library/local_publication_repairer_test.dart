import 'package:fbooks/application/library/local_publication_importer.dart';
import 'package:fbooks/application/library/local_publication_repairer.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalPublicationRepairer', () {
    test(
      'repoints a local publication without changing its metadata',
      () async {
        final original = Publication(
          id: 'book-1',
          source: const LibrarySource(
            id: 'local-library',
            kind: LibrarySourceKind.local,
            name: 'Local library',
          ),
          title: 'A local book',
          authors: const ['Ada'],
          description: 'Metadata remains intact.',
          format: PublicationFormat.epub,
          assets: [
            PublicationAsset(
              id: 'book-1-file',
              publicationId: 'book-1',
              kind: PublicationAssetKind.localFile,
              location: Uri.file('/missing/book.epub'),
              mediaType: 'application/epub+zip',
            ),
          ],
        );
        final repository = _MemoryPublicationRepository([original]);
        final repairer = LocalPublicationRepairer(repository);

        final repaired = await repairer.repair(
          publicationId: original.id,
          replacement: LocalPublicationCandidate(
            fileName: 'Replacement.epub',
            location: Uri.file('/replacement/Replacement.epub'),
          ),
        );

        expect(repaired.id, original.id);
        expect(repaired.title, original.title);
        expect(repaired.authors, original.authors);
        expect(repaired.description, original.description);
        expect(repaired.assets.single.id, 'book-1-file');
        expect(
          repaired.assets.single.location,
          Uri.file('/replacement/Replacement.epub'),
        );
        expect(
          (await repository.findById(original.id))?.assets.single.location,
          Uri.file('/replacement/Replacement.epub'),
        );
      },
    );

    test('rejects a replacement with a different format', () async {
      final repository = _MemoryPublicationRepository([_localEpub()]);
      final repairer = LocalPublicationRepairer(repository);

      expect(
        () => repairer.repair(
          publicationId: 'book-1',
          replacement: LocalPublicationCandidate(
            fileName: 'Other.cbz',
            location: Uri.file('/replacement/Other.cbz'),
          ),
        ),
        throwsArgumentError,
      );
    });

    test(
      'rejects a replacement already assigned to another publication',
      () async {
        final original = _localEpub();
        final alreadyImported = Publication(
          id: 'book-2',
          source: original.source,
          title: 'Another book',
          format: PublicationFormat.epub,
          assets: [
            PublicationAsset(
              id: 'book-2-file',
              publicationId: 'book-2',
              kind: PublicationAssetKind.localFile,
              location: Uri.file('/replacement/Shared.epub'),
            ),
          ],
        );
        final repository = _MemoryPublicationRepository([
          original,
          alreadyImported,
        ]);
        final repairer = LocalPublicationRepairer(repository);

        expect(
          () => repairer.repair(
            publicationId: original.id,
            replacement: LocalPublicationCandidate(
              fileName: 'Shared.epub',
              location: Uri.file('/replacement/Shared.epub'),
            ),
          ),
          throwsStateError,
        );
      },
    );
  });
}

Publication _localEpub() => Publication(
  id: 'book-1',
  source: const LibrarySource(
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
      location: Uri.file('/missing/book.epub'),
    ),
  ],
);

class _MemoryPublicationRepository implements PublicationRepository {
  _MemoryPublicationRepository(List<Publication> publications)
    : _publications = {
        for (final publication in publications) publication.id: publication,
      };

  final Map<PublicationId, Publication> _publications;

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
  Stream<List<Publication>> watchPublications() =>
      Stream.value(_publications.values.toList());
}
