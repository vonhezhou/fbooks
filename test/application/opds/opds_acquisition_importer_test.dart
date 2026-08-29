import 'dart:typed_data';

import 'package:fbooks/application/managed_asset_store.dart';
import 'package:fbooks/application/opds/opds_acquisition_importer.dart';
import 'package:fbooks/application/opds/opds_catalog.dart';
import 'package:fbooks/application/opds/opds_credentials.dart';
import 'package:fbooks/application/opds/opds_credentials_repository.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'downloads an OPDS acquisition and retains remote and local assets',
    () async {
      final repository = _MemoryPublicationRepository();
      final fetcher = _FakeRemoteAssetFetcher();
      final store = _FakeManagedAssetStore();
      final credentials = _FixedCredentialsRepository();
      final importer = OpdsAcquisitionImporter(
        repository,
        fetcher,
        store,
        credentialsRepository: credentials,
      );
      final acquisition = OpdsAcquisition(
        href: Uri.parse('https://books.example.org/book.epub'),
        mediaType: 'application/epub+zip',
      );

      final progress = <OpdsDownloadProgress>[];
      final imported = await importer.acquire(
        source: _source,
        publication: OpdsPublication(
          title: 'Remote book',
          authors: ['Ada'],
          description: 'A downloaded classic.',
          coverUri: Uri.parse('https://books.example.org/covers/book.jpg'),
          acquisitions: [],
        ),
        acquisition: acquisition,
        onProgress: progress.add,
      );
      final duplicate = await importer.acquire(
        source: _source,
        publication: const OpdsPublication(
          title: 'Remote book, revised',
          authors: ['Ada', 'Grace'],
          description: 'Updated catalog metadata.',
          acquisitions: [],
        ),
        acquisition: acquisition,
      );

      expect(imported.assets, hasLength(2));
      expect(imported.assets.first.location, acquisition.href);
      expect(imported.assets.last.location.scheme, 'file');
      expect(imported.description, 'A downloaded classic.');
      expect(
        imported.coverUri,
        Uri.parse('https://books.example.org/covers/book.jpg'),
      );
      expect(store.savedBytes, [1, 2, 3]);
      expect(fetcher.fetchCount, 1);
      expect(fetcher.credentials, credentials.value);
      expect(progress.single.fraction, 1);
      expect(duplicate.id, imported.id);
      expect(duplicate.title, 'Remote book, revised');
      expect(duplicate.authors, ['Ada', 'Grace']);
      expect(duplicate.description, 'Updated catalog metadata.');
      expect(duplicate.assets, imported.assets);
    },
  );

  test('cancels an acquisition before it is persisted', () async {
    final repository = _MemoryPublicationRepository();
    final cancellation = OpdsDownloadCancellation()..cancel();
    final importer = OpdsAcquisitionImporter(
      repository,
      _FakeRemoteAssetFetcher(),
      _FakeManagedAssetStore(),
      credentialsRepository: _FixedCredentialsRepository(),
    );

    await expectLater(
      importer.acquire(
        source: _source,
        publication: const OpdsPublication(
          title: 'Remote book',
          authors: [],
          acquisitions: [],
        ),
        acquisition: OpdsAcquisition(
          href: Uri.parse('https://books.example.org/book.epub'),
          mediaType: 'application/epub+zip',
        ),
        cancellation: cancellation,
      ),
      throwsA(isA<OpdsDownloadCancelled>()),
    );
    expect(await repository.listPublications(), isEmpty);
  });
}

final _source = LibrarySource(
  id: 'opds:https://books.example.org',
  kind: LibrarySourceKind.opds,
  name: 'books.example.org',
  endpoint: Uri(scheme: 'https', host: 'books.example.org'),
);

class _FakeRemoteAssetFetcher implements RemoteAssetFetcher {
  var fetchCount = 0;
  OpdsCredentials? credentials;

  @override
  Future<RemoteAssetResponse> fetch(
    Uri uri, {
    OpdsCredentials? credentials,
  }) async {
    fetchCount++;
    this.credentials = credentials;
    return RemoteAssetResponse(
      bytes: Stream.value(Uint8List.fromList([1, 2, 3])),
      fileName: 'book.epub',
      mediaType: 'application/epub+zip',
      contentLength: 3,
    );
  }
}

class _FixedCredentialsRepository implements OpdsCredentialsRepository {
  final value = const OpdsCredentials(username: 'ada', password: 'secret');

  @override
  Future<void> delete(String sourceId) async {}

  @override
  Future<OpdsCredentials?> load(String sourceId) async => value;

  @override
  Future<void> save(String sourceId, OpdsCredentials credentials) async {}
}

class _FakeManagedAssetStore implements ManagedAssetStore {
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
    return Uri.file('/managed/$assetId.epub');
  }
}

class _MemoryPublicationRepository implements PublicationRepository {
  final Map<PublicationId, Publication> _publications = {};

  @override
  Future<void> delete(PublicationId id) async => _publications.remove(id);

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
