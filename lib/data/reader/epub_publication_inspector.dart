import 'dart:io';
import 'dart:typed_data';

import 'package:epub_pro/epub_pro.dart';
import 'package:fbooks/application/library/publication_format_inspector.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final _logger = Logger('reader.epub_import');

/// Extracts EPUB metadata and its declared package cover when available.
class EpubPublicationInspector implements PublicationFormatInspector {
  @override
  bool supports(PublicationFormat format) => format == PublicationFormat.epub;

  @override
  Future<PublicationInspection?> inspect({
    required PublicationFormat format,
    required Uri location,
  }) async {
    if (!supports(format) || location.scheme != 'file') {
      return null;
    }
    final file = File.fromUri(location);
    if (!await file.exists()) {
      return null;
    }

    EpubBookRef? book;
    try {
      book = await EpubReader.openBook(await file.readAsBytes());
      return PublicationInspection(
        metadata: _metadataFor(book),
        cover: await _coverFor(book),
      );
    } catch (error, stackTrace) {
      _logger.warning(
        'EPUB import inspection failed: errorType=${error.runtimeType}.',
        null,
        stackTrace,
      );
      return null;
    } finally {
      await book?.epubArchive.clear();
    }
  }

  PublicationMetadataPatch? _metadataFor(EpubBookRef book) {
    final title = book.title?.trim();
    final authors = book.authors
        .map((author) => author.trim())
        .where((author) => author.isNotEmpty)
        .toList(growable: false);
    if ((title == null || title.isEmpty) && authors.isEmpty) {
      return null;
    }
    return PublicationMetadataPatch(
      title: title?.isEmpty ?? true ? null : title,
      authors: authors.isEmpty ? null : authors,
    );
  }

  Future<CoverPayload?> _coverFor(EpubBookRef book) async {
    final images = book.content?.images;
    if (images == null || images.isEmpty) {
      return null;
    }
    final manifestItems = book.schema?.package?.manifest?.items ?? const [];
    final manifestCover = _firstWhereOrNull(
      manifestItems,
      (item) => _hasCoverImageProperty(item.properties),
    );
    final legacyCoverId = _firstWhereOrNull(
      book.schema?.package?.metadata?.metaItems ?? const [],
      (item) => item.name?.toLowerCase() == 'cover',
    )?.content;
    final legacyManifestCover = legacyCoverId == null
        ? null
        : _firstWhereOrNull(
            manifestItems,
            (item) => item.id?.toLowerCase() == legacyCoverId.toLowerCase(),
          );
    final manifestItem = manifestCover ?? legacyManifestCover;
    final selected = manifestItem == null
        ? images.entries.first
        : _entryForHref(images, manifestItem.href) ?? images.entries.first;
    final bytes = Uint8List.fromList(await selected.value.readContentAsBytes());
    if (bytes.isEmpty) {
      return null;
    }
    return CoverPayload(
      fileName: path.basename(selected.key),
      bytes: bytes,
      mediaType: manifestItem?.mediaType ?? selected.value.contentMimeType,
    );
  }

  MapEntry<String, T>? _entryForHref<T>(Map<String, T> images, String? href) {
    if (href == null) {
      return null;
    }
    final normalizedHref = _normalizePath(href);
    for (final entry in images.entries) {
      if (_normalizePath(entry.key) == normalizedHref) {
        return entry;
      }
    }
    return null;
  }

  bool _hasCoverImageProperty(String? properties) =>
      properties
          ?.split(RegExp(r'\s+'))
          .any((property) => property.toLowerCase() == 'cover-image') ??
      false;

  T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
    for (final value in values) {
      if (test(value)) {
        return value;
      }
    }
    return null;
  }

  String _normalizePath(String value) => path.posix
      .normalize(value)
      .replaceFirst(RegExp(r'^\./'), '')
      .toLowerCase();
}
