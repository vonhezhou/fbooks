import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:fbooks/application/reader/comic_page_index.dart';
import 'package:fbooks/application/reader/comic_reader_session.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/reading/comic_document.dart';
import 'package:path/path.dart' as path;

class ArchiveComicReaderSessionFactory implements ComicReaderSessionFactory {
  @override
  Future<ComicReaderSession> open(Publication publication) async {
    if (publication.format != PublicationFormat.comicArchive) {
      throw UnsupportedError(
        '${publication.format.name} is not a comic archive',
      );
    }

    final asset = publication.assets
        .where((asset) => asset.kind == PublicationAssetKind.localFile)
        .firstOrNull;
    if (asset == null || asset.location.scheme != 'file') {
      throw UnsupportedError('A local comic archive is required');
    }

    final filePath = asset.location.toFilePath();
    if (path.extension(filePath).toLowerCase() != '.cbz') {
      throw UnsupportedError(
        'Only CBZ archives can be opened in this milestone',
      );
    }
    if (!await File(filePath).exists()) {
      throw FileSystemException(
        'The imported comic file no longer exists',
        filePath,
      );
    }

    final stream = InputFileStream(filePath);
    final archive = ZipDecoder().decodeStream(stream);
    final pageIndex = ComicPageIndex.fromEntryNames(
      archive.files.where((file) => file.isFile).map((file) => file.name),
    );
    if (pageIndex.isEmpty) {
      throw FormatException('The CBZ archive contains no readable images');
    }

    final archiveFiles = {for (final file in archive.files) file.name: file};
    return _ArchiveComicReaderSession(
      document: ComicDocument(publicationId: publication.id, pages: pageIndex),
      archiveFiles: archiveFiles,
    );
  }
}

class _ArchiveComicReaderSession implements ComicReaderSession {
  const _ArchiveComicReaderSession({
    required this.document,
    required this.archiveFiles,
  });

  @override
  final ComicDocument document;
  final Map<String, ArchiveFile> archiveFiles;

  @override
  Future<Uint8List> readPage(int pageIndex) async {
    if (pageIndex < 0 || pageIndex >= document.pages.length) {
      throw RangeError.index(pageIndex, document.pages, 'pageIndex');
    }

    final page = document.pages[pageIndex];
    final bytes = archiveFiles[page.name]?.readBytes();
    if (bytes == null || bytes.isEmpty) {
      throw FormatException('Unable to read comic page ${page.name}');
    }
    return bytes;
  }
}
