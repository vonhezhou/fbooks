import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:epub_pro/epub_pro.dart';
import 'package:fbooks/application/reader/flow_reading_session.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/reading/flow_document.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final _logger = Logger('reader.flow');

class LocalFlowReadingSessionFactory implements FlowReadingSessionFactory {
  @override
  Future<FlowReadingSession> open(Publication publication) async {
    if (publication.format != PublicationFormat.epub &&
        publication.format != PublicationFormat.text) {
      throw UnsupportedError(
        '${publication.format.name} is not reflowable text',
      );
    }

    final asset = publication.assets
        .where((asset) => asset.kind.isReadableLocalFile)
        .firstOrNull;
    if (asset == null || asset.location.scheme != 'file') {
      throw UnsupportedError('A local text asset is required');
    }

    final filePath = asset.location.toFilePath();
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('The imported file no longer exists', filePath);
    }

    return switch (publication.format) {
      PublicationFormat.epub => await _openEpub(publication.id, filePath),
      PublicationFormat.text => _LocalFlowReadingSession(
        FlowDocument(
          publicationId: publication.id,
          chapters: [
            FlowChapter(
              index: 0,
              title: path.basenameWithoutExtension(filePath),
              text: await file.readAsString(),
            ),
          ],
        ),
      ),
      _ => throw UnimplementedError(),
    };
  }

  Future<FlowReadingSession> _openEpub(
    String publicationId,
    String filePath,
  ) async {
    final opened = await _EpubWorkerClient.open(publicationId, filePath);
    _logger.info('EPUB reader session opened.');
    return _LazyEpubFlowReadingSession(
      document: opened.index.document,
      chapters: opened.index.chapters,
      worker: opened.worker,
    );
  }
}

class _EpubDocumentIndex {
  const _EpubDocumentIndex({required this.document, required this.chapters});

  final FlowDocument document;
  final List<_EpubChapterReference> chapters;
}

class _EpubChapterReference {
  const _EpubChapterReference({required this.index, required this.title});

  final int index;
  final String title;
}

class _OpenedEpubWorker {
  const _OpenedEpubWorker({required this.worker, required this.index});

  final _EpubWorkerClient worker;
  final _EpubDocumentIndex index;
}

class _LazyEpubFlowReadingSession implements FlowReadingSession {
  _LazyEpubFlowReadingSession({
    required this.document,
    required this.chapters,
    required this.worker,
  });

  @override
  final FlowDocument document;
  final List<_EpubChapterReference> chapters;
  final _EpubWorkerClient worker;
  final _chapterCache = <int, Future<FlowChapter>>{};
  var _closed = false;

  @override
  Future<FlowChapter> loadChapter(int index) {
    if (_closed) {
      throw StateError('The EPUB reader session is closed');
    }
    if (index < 0 || index >= chapters.length) {
      throw RangeError.index(index, chapters, 'index');
    }
    return _chapterCache.putIfAbsent(index, () => worker.loadChapter(index));
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await worker.close();
  }
}

class _EpubWorkerClient {
  _EpubWorkerClient(this._isolate, this._commandPort);

  final Isolate _isolate;
  final SendPort _commandPort;
  var _closed = false;

  static Future<_OpenedEpubWorker> open(
    String publicationId,
    String filePath,
  ) async {
    final controlPort = ReceivePort();
    final isolate = await Isolate.spawn<SendPort>(
      _runEpubWorker,
      controlPort.sendPort,
      debugName: 'epub-reader',
    );
    final commandPort = await controlPort.first as SendPort;
    controlPort.close();
    final worker = _EpubWorkerClient(isolate, commandPort);
    try {
      final index = await worker._request<_EpubDocumentIndex>(
        _OpenEpubWorkerRequest(
          publicationId: publicationId,
          filePath: filePath,
        ),
      );
      return _OpenedEpubWorker(worker: worker, index: index);
    } catch (_) {
      await worker.close();
      rethrow;
    }
  }

  Future<FlowChapter> loadChapter(int index) {
    if (_closed) {
      throw StateError('The EPUB worker is closed');
    }
    return _request<FlowChapter>(_LoadEpubChapterWorkerRequest(index));
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    try {
      await _request<Object?>(const _CloseEpubWorkerRequest());
    } finally {
      _closed = true;
      _isolate.kill(priority: Isolate.beforeNextEvent);
    }
  }

  Future<T> _request<T>(_EpubWorkerRequest request) async {
    final responsePort = ReceivePort();
    _commandPort.send(_EpubWorkerCommand(request, responsePort.sendPort));
    final response = await responsePort.first;
    responsePort.close();
    return switch (response) {
      _EpubWorkerSuccess(:final value) => value as T,
      _EpubWorkerFailure(:final message) => _workerFailure(message),
      _ => throw StateError('The EPUB worker returned an invalid response'),
    };
  }

  T _workerFailure<T>(String message) {
    final error = FormatException(message);
    _logger.severe(
      'EPUB worker request failed: errorType=${error.runtimeType}.',
    );
    throw error;
  }
}

sealed class _EpubWorkerRequest {
  const _EpubWorkerRequest();
}

class _OpenEpubWorkerRequest extends _EpubWorkerRequest {
  const _OpenEpubWorkerRequest({
    required this.publicationId,
    required this.filePath,
  });

  final String publicationId;
  final String filePath;
}

class _LoadEpubChapterWorkerRequest extends _EpubWorkerRequest {
  const _LoadEpubChapterWorkerRequest(this.index);

  final int index;
}

class _CloseEpubWorkerRequest extends _EpubWorkerRequest {
  const _CloseEpubWorkerRequest();
}

class _EpubWorkerCommand {
  const _EpubWorkerCommand(this.request, this.responsePort);

  final _EpubWorkerRequest request;
  final SendPort responsePort;
}

class _EpubWorkerSuccess {
  const _EpubWorkerSuccess(this.value);

  final Object? value;
}

class _EpubWorkerFailure {
  const _EpubWorkerFailure(this.message);

  final String message;
}

Future<void> _runEpubWorker(SendPort controlPort) async {
  final commands = ReceivePort();
  controlPort.send(commands.sendPort);
  EpubBookRef? book;
  var chapters = const <EpubChapterRef>[];
  await for (final command in commands) {
    if (command is! _EpubWorkerCommand) {
      continue;
    }
    try {
      switch (command.request) {
        case _OpenEpubWorkerRequest(:final publicationId, :final filePath):
          book = await EpubReader.openBook(await File(filePath).readAsBytes());
          chapters = _flattenChapters(book.getChapters()).toList();
          if (chapters.isEmpty) {
            throw FormatException(
              'The EPUB contains no readable spine content',
            );
          }
          command.responsePort.send(
            _EpubWorkerSuccess(
              _buildEpubDocumentIndex(publicationId, chapters),
            ),
          );
        case _LoadEpubChapterWorkerRequest(:final index):
          final openedBook = book;
          if (openedBook == null) {
            throw StateError('The EPUB worker has not opened a publication');
          }
          if (index < 0 || index >= chapters.length) {
            throw RangeError.index(index, chapters, 'index');
          }
          final loadedChapter = await _readEpubChapter(
            openedBook,
            chapters,
            index,
          );
          command.responsePort.send(_EpubWorkerSuccess(loadedChapter));
        case _CloseEpubWorkerRequest():
          command.responsePort.send(const _EpubWorkerSuccess(null));
          commands.close();
          return;
      }
    } catch (error) {
      command.responsePort.send(_EpubWorkerFailure(error.toString()));
    }
  }
}

_EpubDocumentIndex _buildEpubDocumentIndex(
  String publicationId,
  List<EpubChapterRef> chapters,
) {
  final references = [
    for (final (index, chapter) in chapters.indexed)
      _EpubChapterReference(index: index, title: _chapterTitle(chapter, index)),
  ];
  return _EpubDocumentIndex(
    document: FlowDocument(
      publicationId: publicationId,
      chapters: [
        for (final reference in references)
          FlowChapter(index: reference.index, title: reference.title, text: ''),
      ],
      tableOfContents: [
        for (final reference in references)
          FlowTableOfContentsEntry(
            title: reference.title,
            chapterIndex: reference.index,
          ),
      ],
    ),
    chapters: references,
  );
}

Iterable<EpubChapterRef> _flattenChapters(
  Iterable<EpubChapterRef> chapters,
) sync* {
  for (final chapter in chapters) {
    yield chapter;
    yield* _flattenChapters(chapter.subChapters);
  }
}

String _chapterTitle(EpubChapterRef chapter, int index) {
  final title = chapter.title?.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }
  return path.posix.basenameWithoutExtension(
    chapter.contentFileName ?? 'Chapter ${index + 1}',
  );
}

Future<FlowChapter> _readEpubChapter(
  EpubBookRef book,
  List<EpubChapterRef> chapters,
  int index,
) async {
  final chapter = chapters[index];
  final document = html.parse(await chapter.readHtmlContent());
  document.querySelectorAll('script').forEach((element) => element.remove());
  final heading = document.querySelector('h1, h2, h3');
  final title = heading?.text.trim();
  heading?.remove();

  final sourceFileName = chapter.contentFileName;
  await _inlineStyleSheets(document, sourceFileName, book);
  await _inlineImages(document, sourceFileName, book);
  _rewriteInternalLinks(document, sourceFileName, chapters);

  return FlowChapter(
    index: index,
    title: title == null || title.isEmpty
        ? _chapterTitle(chapter, index)
        : title,
    text: document.body?.text.trim() ?? '',
    transitionalHtml: document.outerHtml,
  );
}

Future<void> _inlineStyleSheets(
  dom.Document document,
  String? sourceFileName,
  EpubBookRef book,
) async {
  final css = <String>[];
  for (final link in document.querySelectorAll('link[rel]')) {
    final rel = link.attributes['rel']?.toLowerCase();
    if (rel == null || !rel.split(RegExp(r'\s+')).contains('stylesheet')) {
      continue;
    }
    final stylePath = _resolveEpubPath(sourceFileName, link.attributes['href']);
    if (stylePath != null) {
      final style = _findByNormalizedPath(
        book.content?.css ?? const {},
        stylePath,
      );
      if (style != null) {
        css.add(await style.readContentAsText());
      }
    }
    link.remove();
  }
  if (css.isNotEmpty) {
    (document.head ?? document.documentElement)?.append(
      dom.Element.tag('style')..text = css.join('\n'),
    );
  }
}

Future<void> _inlineImages(
  dom.Document document,
  String? sourceFileName,
  EpubBookRef book,
) async {
  for (final image in document.querySelectorAll('img[src]')) {
    final imagePath = _resolveEpubPath(sourceFileName, image.attributes['src']);
    if (imagePath == null) {
      continue;
    }
    final resource = _findByNormalizedPath(
      book.content?.images ?? const {},
      imagePath,
    );
    if (resource == null) {
      continue;
    }
    final bytes = await resource.readContent();
    final mimeType = resource.contentMimeType ?? 'application/octet-stream';
    image.attributes['src'] = 'data:$mimeType;base64,${base64Encode(bytes)}';
  }
}

void _rewriteInternalLinks(
  dom.Document document,
  String? sourceFileName,
  List<EpubChapterRef> chapters,
) {
  final chapterIndexes = <String, int>{
    for (final (index, chapter) in chapters.indexed)
      if (chapter.contentFileName case final fileName? when fileName.isNotEmpty)
        _normalizeEpubPath(fileName): index,
  };
  for (final link in document.querySelectorAll('a[href]')) {
    final targetPath = _resolveEpubPath(
      sourceFileName,
      link.attributes['href'],
    );
    final index = targetPath == null ? null : chapterIndexes[targetPath];
    if (index != null) {
      link.attributes['href'] = 'fbooks://chapter/$index';
    }
  }
}

String? _resolveEpubPath(String? sourceFileName, String? value) {
  if (sourceFileName == null || value == null || value.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme || uri.hasAuthority) {
    return null;
  }
  final target = uri.path.isEmpty ? sourceFileName : uri.path;
  return _normalizeEpubPath(
    path.posix.join(path.posix.dirname(sourceFileName), target),
  );
}

T? _findByNormalizedPath<T>(Map<String, T> resources, String targetPath) {
  for (final entry in resources.entries) {
    if (_normalizeEpubPath(entry.key) == targetPath) {
      return entry.value;
    }
  }
  return null;
}

String _normalizeEpubPath(String value) => path.posix.normalize(value);

class _LocalFlowReadingSession implements FlowReadingSession {
  const _LocalFlowReadingSession(this.document);

  @override
  final FlowDocument document;

  @override
  Future<FlowChapter> loadChapter(int index) async {
    if (index < 0 || index >= document.chapters.length) {
      throw RangeError.index(index, document.chapters, 'index');
    }
    return document.chapters[index];
  }

  @override
  Future<void> close() async {}
}
