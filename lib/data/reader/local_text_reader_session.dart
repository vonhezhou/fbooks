import 'dart:io';

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
    final chapters = <TextChapter>[];
    final contents = <TextTableOfContentsEntry>[];
    for (final chapter in _flattenChapters(book.chapters)) {
      final mapped = _readEpubChapter(chapter, chapters.length);
      if (mapped.text.isNotEmpty) {
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

  TextChapter _readEpubChapter(EpubChapter chapter, int index) {
    final document = html.parse(chapter.htmlContent ?? '');
    document
        .querySelectorAll('script, style')
        .forEach((element) => element.remove());
    final segments = _readSegments(document.body);
    final body = segments.map((segment) => segment.text).join().trim();
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

  List<TextSegment> _readSegments(dom.Element? body) {
    if (body == null) {
      return const [];
    }
    final segments = <TextSegment>[];
    final blocks = body.querySelectorAll('p, li, blockquote, pre');
    final content = blocks.isEmpty ? <dom.Element>[body] : blocks;
    for (final block in content) {
      final start = segments.length;
      _appendNodeSegments(block, segments);
      if (segments.length > start) {
        segments.add(const TextSegment(text: '\n\n'));
      }
    }
    if (segments.isNotEmpty) {
      segments.removeLast();
    }
    return segments;
  }

  void _appendNodeSegments(
    dom.Node node,
    List<TextSegment> segments, [
    bool emphasized = false,
  ]) {
    if (node is dom.Text) {
      final text = node.data.replaceAll(RegExp(r'\s+'), ' ');
      if (text.isNotEmpty) {
        segments.add(TextSegment(text: text, emphasized: emphasized));
      }
      return;
    }
    if (node is! dom.Element) {
      return;
    }
    final nextEmphasis =
        emphasized || const {'em', 'i', 'strong', 'b'}.contains(node.localName);
    for (final child in node.nodes) {
      _appendNodeSegments(child, segments, nextEmphasis);
    }
  }
}

class _LocalTextReaderSession implements TextReaderSession {
  const _LocalTextReaderSession(this.document);

  @override
  final TextDocument document;
}
