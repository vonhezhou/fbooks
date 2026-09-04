import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:fbooks/application/library/publication_format_inspector.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/application/reader/comic_page_index.dart';
import 'package:fbooks/data/reader/archive_text_decoder.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

final _logger = Logger('reader.comic_import');

class ArchiveComicPublicationInspector implements PublicationFormatInspector {
  @override
  bool supports(PublicationFormat format) =>
      format == PublicationFormat.comicArchive;

  @override
  Future<PublicationInspection?> inspect({
    required PublicationFormat format,
    required Uri location,
  }) async {
    if (!supports(format)) {
      return null;
    }
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
      final comicInfo = _readComicInfo(archive);
      return PublicationInspection(
        metadata: comicInfo?.metadata,
        cover: _readCover(archive, frontCoverIndex: comicInfo?.frontCoverIndex),
      );
    } catch (error, stackTrace) {
      _logger.warning(
        'Comic archive import inspection failed: '
        'errorType=${error.runtimeType}.',
        null,
        stackTrace,
      );
      return null;
    } finally {
      await archive?.clear();
    }
  }

  _ComicInfoData? _readComicInfo(Archive archive) {
    final comicInfo = archive.files.firstWhere(
      (entry) => entry.isFile && entry.name.toLowerCase() == 'comicinfo.xml',
      orElse: () => ArchiveFile.noData(''),
    );
    if (!comicInfo.isFile || comicInfo.name.isEmpty) {
      return null;
    }
    try {
      final text = ArchiveTextDecoder.decodeText(
        comicInfo.readBytes() ?? Uint8List(0),
      );
      if (text == null) {
        return null;
      }
      final document = XmlDocument.parse(text);
      return _ComicInfoData(
        metadata: PublicationMetadataPatch(
          title: _value(document, 'Title'),
          authors: switch (_value(document, 'Writer')) {
            final author? => [author],
            null => null,
          },
          description: _value(document, 'Summary'),
          publishedAt: _publicationDate(document),
          tags: _tags(document),
        ),
        frontCoverIndex: _frontCoverIndex(document),
      );
    } catch (error, stackTrace) {
      _logger.warning(
        'ComicInfo parsing failed: errorType=${error.runtimeType}.',
        null,
        stackTrace,
      );
      return null;
    }
  }

  CoverPayload? _readCover(Archive archive, {int? frontCoverIndex}) {
    final pages = ComicPageIndex.fromEntryNames(
      archive.files.where((entry) => entry.isFile).map((entry) => entry.name),
    );
    if (pages.isEmpty) {
      return null;
    }
    final entryByName = {for (final entry in archive.files) entry.name: entry};
    final coverName =
        frontCoverIndex != null &&
            frontCoverIndex >= 0 &&
            frontCoverIndex < pages.length
        ? pages[frontCoverIndex].name
        : _heuristicCoverName(pages.map((page) => page.name), pages.first.name);
    final entry = entryByName[coverName];
    final bytes = entry?.readBytes();
    if (entry == null || bytes == null || bytes.isEmpty) {
      return null;
    }
    return CoverPayload(
      fileName: coverName,
      bytes: bytes,
      mediaType: _coverMediaType(coverName),
    );
  }

  String _heuristicCoverName(Iterable<String> pageNames, String fallback) {
    final namedCover = pageNames.firstWhere(
      _hasCoverFileName,
      orElse: () => '',
    );
    return namedCover.isNotEmpty
        ? namedCover
        : pageNames.firstWhere(_isComicPackerCover, orElse: () => fallback);
  }

  bool _hasCoverFileName(String entryName) {
    final name = path.basenameWithoutExtension(entryName).toLowerCase();
    return name.contains('cover') ||
        name.contains('front') ||
        name.contains('coverpage') ||
        RegExp(r'^000(?:[._-]|$)').hasMatch(name) ||
        name.startsWith('封面');
  }

  bool _isComicPackerCover(String entryName) => path
      .split(path.dirname(entryName))
      .any((segment) => segment.toLowerCase().contains('000-cover'));

  String? _value(XmlDocument document, String localName) {
    final value = document
        .findAllElements(localName)
        .map((element) => element.innerText.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    return value.isEmpty ? null : value;
  }

  int? _frontCoverIndex(XmlDocument document) => document
      .findAllElements('Page')
      .where((page) => page.getAttribute('Type')?.toLowerCase() == 'frontcover')
      .map((page) => int.tryParse(page.getAttribute('Image') ?? ''))
      .whereType<int>()
      .firstOrNull;

  DateTime? _publicationDate(XmlDocument document) {
    final year = int.tryParse(_value(document, 'Year') ?? '');
    if (year == null || year < 1) {
      return null;
    }
    final month = int.tryParse(_value(document, 'Month') ?? '') ?? 1;
    final day = int.tryParse(_value(document, 'Day') ?? '') ?? 1;
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return DateTime(year);
    }
    final candidate = DateTime(year, month, day);
    return candidate.year == year &&
            candidate.month == month &&
            candidate.day == day
        ? candidate
        : DateTime(year);
  }

  List<String>? _tags(XmlDocument document) {
    final genre = _value(document, 'Genre');
    if (genre == null) {
      return null;
    }
    final tags = genre
        .split(RegExp(r'[,;]'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    return tags.isEmpty ? null : tags;
  }

  String? _coverMediaType(String entryName) =>
      switch (path.extension(entryName).toLowerCase()) {
        '.avif' => 'image/avif',
        '.bmp' => 'image/bmp',
        '.gif' => 'image/gif',
        '.jpeg' || '.jpg' => 'image/jpeg',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        _ => null,
      };
}

class _ComicInfoData {
  const _ComicInfoData({required this.metadata, this.frontCoverIndex});

  final PublicationMetadataPatch metadata;
  final int? frontCoverIndex;
}
