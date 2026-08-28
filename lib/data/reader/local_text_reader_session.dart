import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:fbooks/application/reader/text_reader_session.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/reading/text_document.dart';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

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
    final archive = ZipDecoder().decodeStream(InputFileStream(filePath));
    final files = {
      for (final file in archive.files.where((file) => file.isFile))
        file.name: file,
    };
    final packagePath = _readPackagePath(
      _readUtf8(files, 'META-INF/container.xml'),
    );
    final packageDocument = XmlDocument.parse(_readUtf8(files, packagePath));
    final manifest = <String, String>{};
    String? navigationPath;
    for (final item in packageDocument.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) {
        manifest[id] = href;
        if ((item.getAttribute('properties') ?? '')
            .split(' ')
            .contains('nav')) {
          navigationPath = path.posix.normalize(
            path.posix.join(path.posix.dirname(packagePath), href),
          );
        }
      }
    }

    final chapterPaths = <String>[];
    for (final itemRef in packageDocument.findAllElements('itemref')) {
      final href = manifest[itemRef.getAttribute('idref')];
      if (href != null) {
        chapterPaths.add(
          path.posix.normalize(
            path.posix.join(path.posix.dirname(packagePath), href),
          ),
        );
      }
    }

    final chapters = <TextChapter>[];
    final chapterIndexByPath = <String, int>{};
    for (final chapterPath in chapterPaths) {
      final chapter = _readChapter(files, chapterPath, chapters.length);
      if (chapter.text.isNotEmpty) {
        chapterIndexByPath[chapterPath] = chapters.length;
        chapters.add(chapter);
      }
    }
    if (chapters.isEmpty) {
      throw FormatException('The EPUB contains no readable spine content');
    }

    return TextDocument(
      publicationId: publicationId,
      chapters: chapters,
      tableOfContents: navigationPath == null
          ? const []
          : _readTableOfContents(files, navigationPath, chapterIndexByPath),
    );
  }

  List<TextTableOfContentsEntry> _readTableOfContents(
    Map<String, ArchiveFile> files,
    String navigationPath,
    Map<String, int> chapterIndexByPath,
  ) {
    final document = html.parse(_readUtf8(files, navigationPath));
    final navigation = document.querySelectorAll('nav').where((element) {
      return element.attributes.entries.any(
        (entry) =>
            entry.key.toString().contains('type') &&
            entry.value.split(' ').contains('toc'),
      );
    }).firstOrNull;
    if (navigation == null) {
      return const [];
    }
    return navigation
        .querySelectorAll('a[href]')
        .map((anchor) {
          final target = anchor.attributes['href']!.split('#').first;
          final chapterPath = path.posix.normalize(
            path.posix.join(path.posix.dirname(navigationPath), target),
          );
          final index = chapterIndexByPath[chapterPath];
          return index == null || anchor.text.trim().isEmpty
              ? null
              : TextTableOfContentsEntry(
                  title: anchor.text.trim(),
                  chapterIndex: index,
                );
        })
        .whereType<TextTableOfContentsEntry>()
        .toList(growable: false);
  }

  String _readPackagePath(String containerXml) {
    final document = XmlDocument.parse(containerXml);
    for (final rootFile in document.findAllElements('rootfile')) {
      final fullPath = rootFile.getAttribute('full-path');
      if (fullPath != null && fullPath.isNotEmpty) {
        return fullPath;
      }
    }
    throw FormatException('The EPUB container has no package document');
  }

  TextChapter _readChapter(
    Map<String, ArchiveFile> files,
    String chapterPath,
    int index,
  ) {
    final document = html.parse(_readUtf8(files, chapterPath));
    document
        .querySelectorAll('script, style')
        .forEach((element) => element.remove());
    final segments = _readSegments(document.body);
    final body = segments.map((segment) => segment.text).join().trim();
    final title = document.querySelector('h1, h2, h3')?.text.trim();
    return TextChapter(
      index: index,
      title: title == null || title.isEmpty
          ? path.posix.basenameWithoutExtension(chapterPath)
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

  String _readUtf8(Map<String, ArchiveFile> files, String fileName) {
    final bytes = files[fileName]?.readBytes();
    if (bytes == null) {
      throw FormatException('The EPUB is missing $fileName');
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}

class _LocalTextReaderSession implements TextReaderSession {
  const _LocalTextReaderSession(this.document);

  @override
  final TextDocument document;
}
