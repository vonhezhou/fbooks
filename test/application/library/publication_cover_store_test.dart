import 'dart:typed_data';

import 'package:fbooks/application/managed_asset_store.dart';
import 'package:fbooks/application/library/publication_cover_store.dart';
import 'package:fbooks/application/library/publication_format_inspector.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'replaces only the generated cover and retains remote metadata',
    () async {
      final store = PublicationCoverStore(_ManagedAssetStore());
      final publication = Publication(
        id: 'book-1',
        source: const LibrarySource(
          id: 'opds',
          kind: LibrarySourceKind.opds,
          name: 'OPDS',
        ),
        title: 'Book',
        format: PublicationFormat.epub,
        coverUri: Uri.parse('https://example.test/cover.jpg'),
        assets: [
          PublicationAsset(
            id: 'book-file',
            publicationId: 'book-1',
            kind: PublicationAssetKind.managedFile,
            location: Uri.file('/managed/book.epub'),
          ),
          PublicationAsset(
            id: 'old-cover',
            publicationId: 'book-1',
            kind: PublicationAssetKind.coverImage,
            location: Uri.file('/managed/old-cover.jpg'),
          ),
        ],
      );

      final cover = await store.save(
        publication: publication,
        payload: CoverPayload(
          fileName: 'cover.png',
          bytes: Uint8List.fromList([1, 2, 3]),
          mediaType: 'image/png',
        ),
      );
      final updated = store.replace(publication, cover);

      expect(updated.coverUri, publication.coverUri);
      expect(
        updated.assets.where(
          (asset) => asset.kind == PublicationAssetKind.coverImage,
        ),
        [cover],
      );
      expect(
        updated.assets.singleWhere(
          (asset) => asset.kind == PublicationAssetKind.managedFile,
        ),
        publication.assets.first,
      );
    },
  );
}

class _ManagedAssetStore implements ManagedAssetStore {
  @override
  Future<void> delete(Uri location) async {}

  @override
  Future<Uri> save({
    required String assetId,
    required String fileName,
    required Stream<Uint8List> bytes,
  }) async => Uri.file('/managed/$assetId.$fileName');
}
