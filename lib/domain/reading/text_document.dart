import 'dart:typed_data';

import 'package:fbooks/domain/publication/publication_id.dart';

/// Extracted, reflowable text shared by the reader, TTS, and AI features.
class TextDocument {
  const TextDocument({
    required this.publicationId,
    required this.chapters,
    this.tableOfContents = const [],
  });

  final PublicationId publicationId;
  final List<TextChapter> chapters;
  final List<TextTableOfContentsEntry> tableOfContents;
}

class TextTableOfContentsEntry {
  const TextTableOfContentsEntry({
    required this.title,
    required this.chapterIndex,
  });

  final String title;
  final int chapterIndex;
}

class TextChapter {
  const TextChapter({
    required this.index,
    required this.title,
    required this.text,
    this.segments = const [],
    this.html,
  });

  final int index;
  final String title;
  final String text;
  final List<TextSegment> segments;

  /// EPUB XHTML prepared with its packaged styles and images resolved.
  ///
  /// Plain-text chapters deliberately leave this unset so their lightweight
  /// [TextSegment]-based presentation remains available.
  final String? html;

  bool get isHtml => html != null;
}

/// A small inline style unit retained from EPUB spine markup.
class TextSegment {
  const TextSegment({
    required this.text,
    this.emphasized = false,
    this.linkTargetChapterIndex,
    this.imageBytes,
    this.imageMimeType,
    this.table,
  });

  final String text;
  final bool emphasized;

  /// The chapter targeted by an internal EPUB hyperlink, when available.
  final int? linkTargetChapterIndex;

  /// The image referenced by an EPUB spine document, when available.
  final Uint8List? imageBytes;
  final String? imageMimeType;
  final TextTable? table;

  bool get isImage => imageBytes != null;
  bool get isTable => table != null;
}

/// A reflowable table extracted from an EPUB spine document.
class TextTable {
  const TextTable({required this.rows});

  final List<List<String>> rows;
}
