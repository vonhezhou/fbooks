import 'dart:typed_data';

import 'package:fbooks/application/managed_asset_store.dart';
import 'package:fbooks/application/library/library_publication_remover.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LibraryPublicationRemover', () {
    test('retains a locally imported original file', () async {
      final repository = _MemoryPublicationRepository(_localPublication);
      final store = _RecordingManagedAssetStore();
      final encodingRepository = _EncodingRepository();
      final remover = LibraryPublicationRemover(
        repository,
        store,
        encodingRepository,
      );

      await remover.remove(_localPublication.id, deleteManagedFiles: true);

      expect(await repository.findById(_localPublication.id), isNull);
      expect(store.deletedLocations, isEmpty);
      expect(encodingRepository.deletedPublicationIds, [_localPublication.id]);
    });

    test(
      'deletes the managed copy of a locally imported publication',
      () async {
        final publication = Publication(
          id: 'managed-local-book',
          source: _localPublication.source,
          title: 'Managed local book',
          format: PublicationFormat.epub,
          assets: [
            PublicationAsset(
              id: 'source-file',
              publicationId: 'managed-local-book',
              kind: PublicationAssetKind.importedSource,
              location: Uri.file('/original/book.epub'),
            ),
            PublicationAsset(
              id: 'managed-file',
              publicationId: 'managed-local-book',
              kind: PublicationAssetKind.managedFile,
              location: Uri.file('/managed/book.epub'),
            ),
          ],
        );
        final repository = _MemoryPublicationRepository(publication);
        final store = _RecordingManagedAssetStore();
        final remover = LibraryPublicationRemover(
          repository,
          store,
          _EncodingRepository(),
        );

        await remover.remove(publication.id, deleteManagedFiles: false);

        expect(store.deletedLocations, [Uri.file('/managed/book.epub')]);
      },
    );

    test(
      'deletes a generated cover with a locally imported publication',
      () async {
        final publication = Publication(
          id: 'local-comic',
          source: _localPublication.source,
          title: 'Local comic',
          format: PublicationFormat.comicArchive,
          coverUri: Uri.file('/managed/cover.jpg'),
          assets: [
            PublicationAsset(
              id: 'managed-file',
              publicationId: 'local-comic',
              kind: PublicationAssetKind.managedFile,
              location: Uri.file('/managed/comic.cbz'),
            ),
            PublicationAsset(
              id: 'generated-cover',
              publicationId: 'local-comic',
              kind: PublicationAssetKind.coverImage,
              location: Uri.file('/managed/cover.jpg'),
            ),
          ],
        );
        final store = _RecordingManagedAssetStore();
        final remover = LibraryPublicationRemover(
          _MemoryPublicationRepository(publication),
          store,
          _EncodingRepository(),
        );

        await remover.remove(publication.id, deleteManagedFiles: false);

        expect(
          store.deletedLocations,
          containsAll([
            Uri.file('/managed/comic.cbz'),
            Uri.file('/managed/cover.jpg'),
          ]),
        );
      },
    );

    test('can delete only the managed file for an OPDS download', () async {
      final repository = _MemoryPublicationRepository(_opdsPublication);
      final store = _RecordingManagedAssetStore();
      final remover = LibraryPublicationRemover(
        repository,
        store,
        _EncodingRepository(),
      );

      final result = await remover.remove(
        _opdsPublication.id,
        deleteManagedFiles: true,
      );

      expect(await repository.findById(_opdsPublication.id), isNull);
      expect(store.deletedLocations, [Uri.file('/managed/download.epub')]);
      expect(result.filesNotDeleted, isEmpty);
    });

    test('reports a managed file that could not be deleted', () async {
      final repository = _MemoryPublicationRepository(_opdsPublication);
      final store = _RecordingManagedAssetStore(throwOnDelete: true);
      final remover = LibraryPublicationRemover(
        repository,
        store,
        _EncodingRepository(),
      );

      final result = await remover.remove(
        _opdsPublication.id,
        deleteManagedFiles: true,
      );

      expect(result.filesNotDeleted, [Uri.file('/managed/download.epub')]);
    });
  });
}

class _EncodingRepository implements ComicArchiveFileNameEncodingRepository {
  final deletedPublicationIds = <String>[];

  @override
  Future<void> delete(String publicationId) async {
    deletedPublicationIds.add(publicationId);
  }

  @override
  Future<String?> load(String publicationId) async => null;

  @override
  Future<void> save(String publicationId, String? encodingName) async {}
}

final _localPublication = Publication(
  id: 'local-book',
  source: LibrarySource(
    id: 'local-library',
    kind: LibrarySourceKind.local,
    name: 'Local library',
  ),
  title: 'Local book',
  format: PublicationFormat.epub,
  assets: [
    PublicationAsset(
      id: 'local-file',
      publicationId: 'local-book',
      kind: PublicationAssetKind.localFile,
      location: Uri(scheme: 'file', path: '/books/original.epub'),
    ),
  ],
);

final _opdsPublication = Publication(
  id: 'remote-book',
  source: LibrarySource(
    id: 'opds:https://books.example.org',
    kind: LibrarySourceKind.opds,
    name: 'Example catalog',
  ),
  title: 'Downloaded book',
  format: PublicationFormat.epub,
  assets: [
    PublicationAsset(
      id: 'remote-file',
      publicationId: 'remote-book',
      kind: PublicationAssetKind.remoteAcquisition,
      location: Uri(
        scheme: 'https',
        host: 'books.example.org',
        path: '/book.epub',
      ),
    ),
    PublicationAsset(
      id: 'managed-file',
      publicationId: 'remote-book',
      kind: PublicationAssetKind.localFile,
      location: Uri(scheme: 'file', path: '/managed/download.epub'),
    ),
  ],
);

class _MemoryPublicationRepository implements PublicationRepository {
  _MemoryPublicationRepository(Publication publication)
    : _publications = {publication.id: publication};

  final Map<PublicationId, Publication> _publications;

  @override
  Future<void> delete(PublicationId id) async {
    _publications.remove(id);
  }

  @override
  Future<Publication?> findByAssetLocation(Uri location) async => null;

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

class _RecordingManagedAssetStore implements ManagedAssetStore {
  _RecordingManagedAssetStore({this.throwOnDelete = false});

  final bool throwOnDelete;
  final deletedLocations = <Uri>[];

  @override
  Future<void> delete(Uri location) async {
    deletedLocations.add(location);
    if (throwOnDelete) {
      throw StateError('The file is locked');
    }
  }

  @override
  Future<Uri> save({
    required String assetId,
    required String fileName,
    required Stream<Uint8List> bytes,
  }) => throw UnimplementedError();
}
