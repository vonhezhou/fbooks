import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:fbooks/application/reader/comic_page_index.dart';
import 'package:fbooks/application/reader/comic_reader_session.dart';
import 'package:fbooks/data/reader/archive_text_decoder.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding_repository.dart';
import 'package:fbooks/domain/reading/comic_document.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final _logger = Logger('reader.comic');

class ArchiveComicReaderSessionFactory implements ComicReaderSessionFactory {
  ArchiveComicReaderSessionFactory(this._encodingRepository);

  final ComicArchiveFileNameEncodingRepository _encodingRepository;

  @override
  Future<ComicReaderSession> open(Publication publication) async {
    if (publication.format != PublicationFormat.comicArchive) {
      throw UnsupportedError(
        '${publication.format.name} is not a comic archive',
      );
    }

    final asset = publication.assets
        .where((asset) => asset.kind.isReadableLocalFile)
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
    final override = ComicArchiveFileNameEncodingX.fromStorageName(
      await _encodingRepository.load(publication.id),
    );
    ArchiveTextDecoder.normalizeEntryNames(
      archive.files,
      override: override == ComicArchiveFileNameEncoding.auto ? null : override,
    );
    final pageIndex = ComicPageIndex.fromEntryNames(
      archive.files.where((file) => file.isFile).map((file) => file.name),
    );
    if (pageIndex.isEmpty) {
      throw FormatException('The CBZ archive contains no readable images');
    }

    final archiveFiles = {for (final file in archive.files) file.name: file};
    _logger.info('Comic reader session opened: pages=${pageIndex.length}.');
    return _ArchiveComicReaderSession(
      document: ComicDocument(publicationId: publication.id, pages: pageIndex),
      archive: archive,
      archiveFiles: archiveFiles,
    );
  }
}

class _ArchiveComicReaderSession implements ComicReaderSession {
  const _ArchiveComicReaderSession({
    required this.document,
    required this.archive,
    required this.archiveFiles,
  });

  @override
  final ComicDocument document;
  final Archive archive;
  final Map<String, ArchiveFile> archiveFiles;

  @override
  Future<Uint8List> readPage(int pageIndex) async {
    if (pageIndex < 0 || pageIndex >= document.pages.length) {
      throw RangeError.index(pageIndex, document.pages, 'pageIndex');
    }

    final page = document.pages[pageIndex];
    try {
      final archiveFile = archiveFiles[page.name];
      if (archiveFile == null) {
        throw FormatException('Unable to read comic page ${page.name}');
      }
      final output = OutputMemoryStream();
      archiveFile.writeContent(output);
      final bytes = output.getBytes();
      if (bytes.isEmpty) {
        throw FormatException('Unable to read comic page ${page.name}');
      }
      return bytes;
    } catch (error, stackTrace) {
      _logger.severe(
        'Comic page read failed: errorType=${error.runtimeType}.',
        null,
        stackTrace,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<void> close() => archive.clear();
}
