import 'dart:io';
import 'dart:typed_data';

import 'package:fbooks/application/managed_asset_store.dart';
import 'package:fbooks/application/library/local_publication_importer.dart';
import 'package:fbooks/application/library/publication_cover_store.dart';
import 'package:fbooks/application/library/publication_format_inspector.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'imports a supported local publication with a managed-file asset',
    () async {
      final repository = _MemoryPublicationRepository();
      final importer = LocalPublicationImporter(
        repository,
        _FakeManagedAssetStore(),
      );

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
        result.imported.single.assets
            .firstWhere(
              (asset) => asset.kind == PublicationAssetKind.importedSource,
            )
            .location
            .toFilePath(),
        '/books/The Sandman.cbz',
      );
      expect(
        result.imported.single.assets
            .singleWhere(
              (asset) => asset.kind == PublicationAssetKind.managedFile,
            )
            .location
            .path,
        startsWith('/managed/'),
      );
      expect(await repository.listPublications(), hasLength(1));
    },
  );

  test('does not import the same local file twice', () async {
    final repository = _MemoryPublicationRepository();
    final importer = LocalPublicationImporter(
      repository,
      _FakeManagedAssetStore(),
    );
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

  test('copies a selected local file into Fbooks-managed storage', () async {
    final source = File(
      '${Directory.systemTemp.path}/fbooks-local-import-source.txt',
    );
    await source.writeAsBytes([70, 98, 111, 111, 107, 115]);
    addTearDown(() async {
      if (await source.exists()) {
        await source.delete();
      }
    });
    final store = _RecordingManagedAssetStore();
    final importer = LocalPublicationImporter(
      _MemoryPublicationRepository(),
      store,
    );

    await importer.importCandidates([
      LocalPublicationCandidate(fileName: 'source.txt', location: source.uri),
    ]);

    expect(store.savedBytes, [70, 98, 111, 111, 107, 115]);
  });

  test('uses CBZ metadata and persists its extracted cover', () async {
    final repository = _MemoryPublicationRepository();
    final importer = LocalPublicationImporter(
      repository,
      _FakeManagedAssetStore(),
      publicationFormatInspector: _ComicPublicationInspector(),
      publicationCoverStore: PublicationCoverStore(_FakeManagedAssetStore()),
    );

    final result = await importer.importCandidates([
      LocalPublicationCandidate(
        fileName: 'fallback.cbz',
        location: Uri.file('/books/fallback.cbz'),
      ),
    ]);

    expect(result.imported.single.title, 'ComicInfo title');
    expect(result.imported.single.authors, ['Writer']);
    expect(result.imported.single.description, 'Summary');
    expect(result.imported.single.coverUri, isNull);
    expect(
      result.imported.single.assets
          .singleWhere((asset) => asset.kind == PublicationAssetKind.coverImage)
          .mediaType,
      'image/jpeg',
    );
  });

  test(
    'reports unsupported file extensions without writing metadata',
    () async {
      final repository = _MemoryPublicationRepository();
      final importer = LocalPublicationImporter(
        repository,
        _FakeManagedAssetStore(),
      );
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
    final importer = LocalPublicationImporter(
      repository,
      _FakeManagedAssetStore(),
    );
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

class _FakeManagedAssetStore implements ManagedAssetStore {
  @override
  Future<void> delete(Uri location) async {}

  @override
  Future<Uri> save({
    required String assetId,
    required String fileName,
    required Stream<Uint8List> bytes,
  }) async => Uri.file('/managed/$assetId.$fileName');
}

class _RecordingManagedAssetStore implements ManagedAssetStore {
  List<int> savedBytes = [];

  @override
  Future<void> delete(Uri location) async {}

  @override
  Future<Uri> save({
    required String assetId,
    required String fileName,
    required Stream<Uint8List> bytes,
  }) async {
    savedBytes = await bytes.expand((chunk) => chunk).toList();
    return Uri.file('/managed/$assetId.$fileName');
  }
}

class _ComicPublicationInspector implements PublicationFormatInspector {
  @override
  bool supports(PublicationFormat format) =>
      format == PublicationFormat.comicArchive;

  @override
  Future<PublicationInspection?> inspect({
    required PublicationFormat format,
    required Uri location,
  }) async => PublicationInspection(
    metadata: const PublicationMetadataPatch(
      title: 'ComicInfo title',
      authors: ['Writer'],
      description: 'Summary',
    ),
    cover: CoverPayload(
      fileName: 'folder/cover.jpg',
      bytes: Uint8List.fromList([1, 2, 3]),
      mediaType: 'image/jpeg',
    ),
  );
}
