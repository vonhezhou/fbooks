import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:fbooks/application/reader/comic_archive_metadata.dart';
import 'package:fbooks/data/reader/archive_text_decoder.dart';
import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

final _logger = Logger('reader.comic_metadata');

class ArchiveComicMetadataReader implements ComicArchiveMetadataReader {
  @override
  Future<ComicArchiveMetadata?> read(Uri location) async {
    if (location.scheme != 'file') {
      return null;
    }
    final filePath = location.toFilePath();
    if (!await File(filePath).exists()) {
      return null;
    }

    Archive? archive;
    try {
      archive = ZipDecoder().decodeStream(InputFileStream(filePath));
      ArchiveTextDecoder.normalizeEntryNames(archive.files);
      final comicInfo = archive.files.firstWhere(
        (entry) => entry.isFile && entry.name.toLowerCase() == 'comicinfo.xml',
        orElse: () => ArchiveFile.noData(''),
      );
      if (!comicInfo.isFile || comicInfo.name.isEmpty) {
        return null;
      }
      final text = ArchiveTextDecoder.decodeText(
        comicInfo.readBytes() ?? Uint8List(0),
      );
      if (text == null) {
        return null;
      }
      final document = XmlDocument.parse(text);
      return ComicArchiveMetadata(
        title: _value(document, 'Title'),
        author: _value(document, 'Writer'),
        description: _value(document, 'Summary'),
      );
    } catch (error, stackTrace) {
      _logger.warning(
        'ComicInfo parsing failed: errorType=${error.runtimeType}.',
        null,
        stackTrace,
      );
      return null;
    } finally {
      await archive?.clear();
    }
  }

  String? _value(XmlDocument document, String localName) {
    final value = document
        .findAllElements(localName)
        .map((element) => element.innerText.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    return value.isEmpty ? null : value;
  }
}
