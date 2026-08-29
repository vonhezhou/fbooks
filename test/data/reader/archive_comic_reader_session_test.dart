import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fbooks/data/reader/archive_comic_reader_session.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opens a CBZ and reads naturally ordered image pages', () async {
    final directory = await Directory.systemTemp.createTemp('fbooks-cbz-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/sample.cbz');

    final archive = Archive()
      ..addFile(ArchiveFile('chapter/10.jpg', 1, [10]))
      ..addFile(ArchiveFile('chapter/2.jpg', 1, [2]))
      ..addFile(ArchiveFile('chapter/1.jpg', 1, [1]));
    await file.writeAsBytes(ZipEncoder().encode(archive));

    final publication = Publication(
      id: 'sample',
      source: const LibrarySource(
        id: 'local-library',
        kind: LibrarySourceKind.local,
        name: 'Local library',
      ),
      title: 'Sample',
      format: PublicationFormat.comicArchive,
      assets: [
        PublicationAsset(
          id: 'sample-file',
          publicationId: 'sample',
          kind: PublicationAssetKind.localFile,
          location: Uri.file(file.path),
        ),
      ],
    );

    final session = await ArchiveComicReaderSessionFactory(
      _MemoryEncodingRepository(),
    ).open(publication);

    expect(session.document.pages.map((page) => page.name), [
      'chapter/1.jpg',
      'chapter/2.jpg',
      'chapter/10.jpg',
    ]);
    expect(await session.readPage(1), [2]);
    await session.close();
  });
}

class _MemoryEncodingRepository
    implements ComicArchiveFileNameEncodingRepository {
  @override
  Future<void> delete(PublicationId publicationId) async {}

  @override
  Future<String?> load(PublicationId publicationId) async => null;

  @override
  Future<void> save(PublicationId publicationId, String? encodingName) async {}
}
