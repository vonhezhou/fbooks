import 'dart:io';
import 'dart:typed_data';

import 'package:epub_pro/epub_pro.dart';
import 'package:fbooks/application/reader/text_reader_session.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/reading/text_document.dart';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:path/path.dart' as path;

class LocalTextReaderSessionFactory implements TextReaderSessionFactory {
  @override
  Future<TextReaderSession> open(Publication publication) async {
    if (publication.format != PublicationFormat.epub &&
        publication.format != PublicationFormat.text) {
      throw UnsupportedError(
        '${publication.format.name} is not reflowable text',
      );
    }

    final asset = publication.assets
        .where((asset) => asset.kind == PublicationAssetKind.localFile)
        .firstOrNull;
    if (asset == null || asset.location.scheme != 'file') {
      throw UnsupportedError('A local text asset is required');
    }

    final filePath = asset.location.toFilePath();
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('The imported file no longer exists', filePath);
    }

    final document = switch (publication.format) {
      PublicationFormat.epub => await _openEpub(publication.id, filePath),
      PublicationFormat.text => TextDocument(
        publicationId: publication.id,
        chapters: [
          TextChapter(
            index: 0,
            title: path.basenameWithoutExtension(filePath),
            text: await file.readAsString(),
          ),
        ],
      ),
      _ => throw UnimplementedError(),
    };
    return _LocalTextReaderSession(document);
  }

  Future<TextDocument> _openEpub(String publicationId, String filePath) async {
    final book = await EpubReader.readBook(await File(filePath).readAsBytes());
    final images =
        book.content?.images ?? const <String, EpubByteContentFile>{};
    final epubChapters = _flattenChapters(book.chapters).toList();
    final readableChapters = <EpubChapter>[];
    for (final chapter in epubChapters) {
      final preview = _readEpubChapter(chapter, 0, const {}, images);
      if (preview.text.isNotEmpty ||
          preview.segments.any(
            (segment) => segment.isImage || segment.isTable,
          )) {
        readableChapters.add(chapter);
      }
    }
    final chapterIndexes = <String, int>{
      for (final (index, chapter) in readableChapters.indexed)
        if (chapter.contentFileName case final fileName?
            when fileName.isNotEmpty)
          _normalizeEpubPath(fileName): index,
    };
    final chapters = <TextChapter>[];
    final contents = <TextTableOfContentsEntry>[];
    for (final (index, chapter) in readableChapters.indexed) {
      final mapped = _readEpubChapter(chapter, index, chapterIndexes, images);
      chapters.add(mapped);
      if (chapter.title case final title? when title.trim().isNotEmpty) {
        contents.add(
          TextTableOfContentsEntry(
            title: title.trim(),
            chapterIndex: mapped.index,
          ),
        );
      }
    }
    if (chapters.isEmpty) {
      throw FormatException('The EPUB contains no readable spine content');
    }

    return TextDocument(
      publicationId: publicationId,
      chapters: chapters,
      tableOfContents: contents,
    );
  }

  Iterable<EpubChapter> _flattenChapters(Iterable<EpubChapter> chapters) sync* {
    for (final chapter in chapters) {
      yield chapter;
      yield* _flattenChapters(chapter.subChapters);
    }
  }

  TextChapter _readEpubChapter(
    EpubChapter chapter,
    int index,
    Map<String, int> chapterIndexes,
    Map<String, EpubByteContentFile> images,
  ) {
    final document = html.parse(chapter.htmlContent ?? '');
    document
        .querySelectorAll('script, style')
        .forEach((element) => element.remove());
    final segments = _readSegments(
      document.body,
      sourceFileName: chapter.contentFileName,
      chapterIndexes: chapterIndexes,
      images: images,
    );
    final body = segments
        .where((segment) => !segment.isImage && !segment.isTable)
        .map((segment) => segment.text)
        .join()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    final title = document.querySelector('h1, h2, h3')?.text.trim();
    return TextChapter(
      index: index,
      title: title == null || title.isEmpty
          ? chapter.title ??
                path.posix.basenameWithoutExtension(
                  chapter.contentFileName ?? 'Chapter ${index + 1}',
                )
          : title,
      text: body,
      segments: segments,
    );
  }

  List<TextSegment> _readSegments(
    dom.Element? body, {
    required String? sourceFileName,
    required Map<String, int> chapterIndexes,
    required Map<String, EpubByteContentFile> images,
  }) {
    if (body == null) {
      return const [];
    }
    final segments = <TextSegment>[];
    const blockSelector = 'p, li, blockquote, pre, figure, img, table';
    final blocks = body
        .querySelectorAll(blockSelector)
        .where((block) => !_hasBlockAncestor(block))
        .toList();
    final content = blocks.isEmpty ? <dom.Element>[body] : blocks;
    for (final block in content) {
      final start = segments.length;
      _appendNodeSegments(
        block,
        segments,
        sourceFileName: sourceFileName,
        chapterIndexes: chapterIndexes,
        images: images,
      );
      if (segments.length > start) {
        segments.add(const TextSegment(text: '\n\n'));
      }
    }
    if (segments.isNotEmpty) {
      segments.removeLast();
    }
    return segments;
  }

  bool _hasBlockAncestor(dom.Element element) {
    const blockElements = {'p', 'li', 'blockquote', 'pre', 'figure', 'table'};
    dom.Node? ancestor = element.parent;
    while (ancestor is dom.Element) {
      if (blockElements.contains(ancestor.localName)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  void _appendNodeSegments(
    dom.Node node,
    List<TextSegment> segments, {
    required String? sourceFileName,
    required Map<String, int> chapterIndexes,
    required Map<String, EpubByteContentFile> images,
    bool emphasized = false,
    int? linkTargetChapterIndex,
  }) {
    if (node is dom.Text) {
      final text = node.data.replaceAll(RegExp(r'\s+'), ' ');
      if (text.isNotEmpty) {
        segments.add(
          TextSegment(
            text: text,
            emphasized: emphasized,
            linkTargetChapterIndex: linkTargetChapterIndex,
          ),
        );
      }
      return;
    }
    if (node is! dom.Element) {
      return;
    }
    if (node.localName == 'img') {
      final image = _resolveImage(
        sourceFileName,
        node.attributes['src'],
        images,
      );
      if (image?.content case final content? when content.isNotEmpty) {
        segments.add(
          TextSegment(
            text: '',
            imageBytes: Uint8List.fromList(content),
            imageMimeType: image?.contentMimeType,
          ),
        );
      }
      return;
    }
    if (node.localName == 'table') {
      final rows = _readTableRows(node);
      if (rows.isNotEmpty) {
        segments.add(
          TextSegment(
            text: '',
            table: TextTable(rows: rows),
          ),
        );
      }
      return;
    }
    final nextEmphasis =
        emphasized || const {'em', 'i', 'strong', 'b'}.contains(node.localName);
    final nextLinkTarget = node.localName == 'a'
        ? _resolveInternalLink(
            sourceFileName,
            node.attributes['href'],
            chapterIndexes,
          )
        : linkTargetChapterIndex;
    for (final child in node.nodes) {
      _appendNodeSegments(
        child,
        segments,
        sourceFileName: sourceFileName,
        chapterIndexes: chapterIndexes,
        images: images,
        emphasized: nextEmphasis,
        linkTargetChapterIndex: nextLinkTarget,
      );
    }
  }

  String _normalizeEpubPath(String value) => path.posix.normalize(value);

  int? _resolveInternalLink(
    String? sourceFileName,
    String? href,
    Map<String, int> chapterIndexes,
  ) {
    if (sourceFileName == null || href == null || href.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(href);
    if (uri == null || uri.hasScheme || uri.hasAuthority) {
      return null;
    }
    final targetPath = uri.path.isEmpty
        ? sourceFileName
        : path.posix.join(path.posix.dirname(sourceFileName), uri.path);
    return chapterIndexes[_normalizeEpubPath(targetPath)];
  }

  EpubByteContentFile? _resolveImage(
    String? sourceFileName,
    String? source,
    Map<String, EpubByteContentFile> images,
  ) {
    if (sourceFileName == null || source == null || source.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(source);
    if (uri == null || uri.hasScheme || uri.hasAuthority) {
      return null;
    }
    final imagePath = uri.path.isEmpty
        ? sourceFileName
        : path.posix.join(path.posix.dirname(sourceFileName), uri.path);
    return images[_normalizeEpubPath(imagePath)];
  }

  List<List<String>> _readTableRows(dom.Element table) => [
    for (final row in table.querySelectorAll('tr'))
      [
        for (final cell in row.querySelectorAll('th, td'))
          cell.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
      ]..removeWhere((cell) => cell.isEmpty),
  ]..removeWhere((row) => row.isEmpty);
}

class _LocalTextReaderSession implements TextReaderSession {
  const _LocalTextReaderSession(this.document);

  @override
  final TextDocument document;
}
