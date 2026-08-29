import 'dart:typed_data';

import 'package:fbooks/domain/publication/publication_id.dart';

/// Extracted, reflowable content shared by every flow-reading format.
class FlowDocument {
  const FlowDocument({
    required this.publicationId,
    required this.chapters,
    this.tableOfContents = const [],
  });

  final PublicationId publicationId;
  final List<FlowChapter> chapters;
  final List<FlowTableOfContentsEntry> tableOfContents;
}

class FlowTableOfContentsEntry {
  const FlowTableOfContentsEntry({
    required this.title,
    required this.chapterIndex,
  });

  final String title;
  final int chapterIndex;
}

class FlowChapter {
  const FlowChapter({
    required this.index,
    required this.title,
    required this.text,
    this.inlines = const [],
    this.transitionalHtml,
  });

  final int index;
  final String title;
  final String text;
  final List<FlowInline> inlines;

  /// EPUB XHTML prepared with its packaged styles and images resolved.
  ///
  /// This is a temporary presentation adapter while EPUB is migrated to
  /// semantic flow blocks. Plain-text chapters leave it unset and render the
  /// lightweight [FlowInline]-based representation directly.
  final String? transitionalHtml;

  bool get hasTransitionalHtml => transitionalHtml != null;
}

/// A small inline content unit rendered by the shared flow reader.
class FlowInline {
  const FlowInline({
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
  final FlowTable? table;

  bool get isImage => imageBytes != null;
  bool get isTable => table != null;
}

/// A reflowable table extracted from an EPUB spine document.
class FlowTable {
  const FlowTable({required this.rows});

  final List<List<String>> rows;
}
