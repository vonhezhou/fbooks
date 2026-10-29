import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fbooks/application/reader/comic_reader_session.dart';
import 'package:fbooks/application/reader/flow_reading_session.dart';
import 'package:fbooks/data/reader/archive_comic_reader_session.dart';
import 'package:fbooks/data/reader/local_flow_reading_session.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding_repository.dart';
import 'package:fbooks/domain/reading/flow_document.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/text_reading_preferences.dart';
import 'package:fbooks/features/reader/presentation/flow_content_viewport.dart';
import 'package:fbooks/features/reader/presentation/flow_reader_page.dart';
import 'package:pdfrx/pdfrx.dart';

import 'page_sources.dart';

/// 仅用于独立实验；不访问书库、进度或持久化偏好。
class RealPageSource extends ChangeNotifier {
  RealPageSource({this.paths = configuredPaths});

  final Map<PageKind, String> paths;
  static const configuredPaths = {
    PageKind.text: String.fromEnvironment('CURL_EPUB_PATH'),
    PageKind.comic: String.fromEnvironment('CURL_CBZ_PATH'),
    PageKind.pdf: String.fromEnvironment('CURL_PDF_PATH'),
  };
  bool has(PageKind kind) => paths[kind]?.isNotEmpty ?? false;
  PageKind? _openKind;
  ComicReaderSession? _comic;
  FlowReadingSession? _flow;
  PdfDocument? _pdf;
  FlowChapter? chapter;
  Size size = Size.zero;
  final boundary = GlobalKey();
  FlowPagination? pagination;
  int pageCount = 0;
  int generation = 0;
  bool capturing = false;
  Map<String, Object> metadata = {};

  Future<void> closeSession() async {
    await _comic?.close();
    await _flow?.close();
    await _pdf?.dispose();
    _openKind = null;
    _comic = null;
    _flow = null;
    _pdf = null;
    chapter = null;
    capturing = false;
    pagination = null;
    pageCount = 0;
  }

  Future<void> open(PageKind kind, Size pageSize) async {
    // 同格式切换单双页只需重排，复用解析结果与原生文件句柄。
    final reused = _openKind == kind && has(kind);
    if (!reused) await closeSession();
    size = pageSize;
    pagination = null;
    capturing = false;
    metadata = {
      'source_is_real': false,
      'input_format': 'synthetic-${kind.name}',
    };
    generation++;
    notifyListeners();
    if (!has(kind)) return;
    final watch = Stopwatch()..start();
    final format = switch (kind) {
      PageKind.text => PublicationFormat.epub,
      PageKind.comic => PublicationFormat.comicArchive,
      PageKind.pdf => PublicationFormat.pdf,
    };
    final publication = Publication(
      id: 'curl-real',
      source: const LibrarySource(
        id: 'curl-lab',
        kind: LibrarySourceKind.local,
        name: 'lab',
      ),
      title: 'lab',
      format: format,
      assets: [
        PublicationAsset(
          id: 'lab-file',
          publicationId: 'curl-real',
          kind: PublicationAssetKind.localFile,
          location: Uri.file(paths[kind]!),
        ),
      ],
    );
    try {
      switch (kind) {
        case PageKind.comic:
          if (!reused) {
            _comic = await ArchiveComicReaderSessionFactory(_Encoding())
                .open(publication);
          }
          pageCount = _comic!.document.pages.length;
        case PageKind.pdf:
          if (!reused) {
            await pdfrxFlutterInitialize();
            _pdf = await PdfDocument.openFile(paths[kind]!);
          }
          pageCount = _pdf!.pages.length;
        case PageKind.text:
          if (!reused) {
            _flow = await LocalFlowReadingSessionFactory().open(publication);
            // 跳过封面和短目录，明确只测一个真实正文章节，不冒充整书页码。
            for (var i = 0; i < _flow!.document.chapters.length; i++) {
              final candidate = await _flow!.loadChapter(i);
              if (candidate.text.length >= 12000) {
                chapter = candidate;
                break;
              }
            }
            if (chapter == null) {
              throw StateError('No sufficiently long EPUB chapter');
            }
          }
          capturing = true;
          notifyListeners();
          await _waitFor(() => pagination != null);
          pageCount = pagination!.pageCount;
          capturing = false;
          notifyListeners();
      }
      _openKind = kind;
      metadata = {
        'source_is_real': true,
        'source_session_reused': reused,
        'input_format': format.name,
        'source_open_ms': watch.elapsedMicroseconds / 1000,
        'source_page_count': pageCount,
        if (chapter != null) 'chapter_index': chapter!.index,
        if (chapter != null) 'pagination_scope': 'selected-chapter',
      };
    } catch (_) {
      await closeSession();
      rethrow;
    }
  }

  Future<void> _waitFor(bool Function() ready) async {
    final deadline = Stopwatch()..start();
    var stable = 0;
    var lastPageCount = -1;
    while (stable < 3) {
      if (deadline.elapsed > const Duration(seconds: 30)) {
        throw StateError('EPUB pagination did not settle');
      }
      await WidgetsBinding.instance.endOfFrame;
      final count = pagination?.pageCount ?? 0;
      stable =
          ready() &&
              count == lastPageCount &&
              PaintingBinding.instance.imageCache.pendingImageCount == 0
          ? stable + 1
          : 0;
      lastPageCount = count;
    }
  }

  Future<ui.Image> load(int index, double dpr) async {
    if (index < 0) throw RangeError.value(index);
    final width = (size.width * dpr).ceil();
    final height = (size.height * dpr).ceil();
    // 最后一张纸的背面仍需要纹理；超尾显示空白，不循环冒充实际页。
    if (index >= pageCount) return _paper(null, width, height);
    if (_flow != null) return capturePage(index, dpr);
    ui.Image image;
    if (_comic != null) {
      final bytes = await _comic!.readPage(index);
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      ui.ImageDescriptor? descriptor;
      ui.Codec? codec;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        final scale = math.min(
          width / descriptor.width,
          height / descriptor.height,
        );
        codec = await descriptor.instantiateCodec(
          targetWidth: math.max(1, (descriptor.width * scale).round()),
          targetHeight: math.max(1, (descriptor.height * scale).round()),
        );
        image = (await codec.getNextFrame()).image;
      } finally {
        codec?.dispose();
        descriptor?.dispose();
        buffer.dispose();
      }
    } else {
      final page = _pdf!.pages[index];
      final scale = math.min(width / page.width, height / page.height);
      final pixels = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
      );
      if (pixels == null) throw StateError('PDF render returned no pixels');
      try {
        image = await pixels.createImage();
      } finally {
        pixels.dispose();
      }
    }
    try {
      return await _paper(image, width, height);
    } finally {
      image.dispose();
    }
  }

  Future<ui.Image> capturePage(int index, double dpr) async {
    capturing = true;
    notifyListeners();
    try {
      pagination!.onPageSelected(index);
      await _waitFor(() => pagination?.pageIndex == index);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return await render.toImage(pixelRatio: dpr);
    } finally {
      capturing = false;
      notifyListeners();
    }
  }

  Future<ui.Image> _paper(ui.Image? image, int width, int height) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    if (image != null) {
      canvas.drawImage(
        image,
        Offset((width - image.width) / 2, (height - image.height) / 2),
        Paint(),
      );
    }
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }
}

class RealPageHost extends StatefulWidget {
  const RealPageHost({super.key, required this.source, required this.child});
  final RealPageSource source;
  final Widget child;

  @override
  State<RealPageHost> createState() => _RealPageHostState();
}

class _RealPageHostState extends State<RealPageHost> {
  FlowChapter? _chapter;
  int _generation = -1;
  Widget? _content;

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    return Stack(
      children: [
        ListenableBuilder(
          listenable: source,
          builder: (context, _) {
            final chapter = source.chapter;
            if (chapter == null) {
              _chapter = null;
              _content = null;
            } else if (!identical(_chapter, chapter) ||
                _generation != source.generation) {
              _chapter = chapter;
              _generation = source.generation;
              // 开关绘制时复用同一子树，避免父级重建触发分页重新测量与锚点恢复。
              _content = RepaintBoundary(
                key: source.boundary,
                child: Material(
                  color: Colors.white,
                  child: FlowChapterRenderer(
                    key: ValueKey(source.generation),
                    chapter: chapter,
                    initialPosition: TextOffsetLocator(
                      chapterIndex: chapter.index,
                      offset: 0,
                    ),
                    preferences: TextReadingPreferences.defaults,
                    onPositionChanged: (_) {},
                    onChapterSelected: (_) {},
                    onPaginationChanged: (value) => source.pagination = value,
                  ),
                ),
              );
            }
            return Positioned(
              left: 0,
              top: 0,
              width: source.size.width,
              height: source.size.height,
              // 后台捕获树不属于可交互页面，避免向无障碍树重复暴露正文。
              child: ExcludeSemantics(
                child: Offstage(
                  offstage: chapter == null || !source.capturing,
                  child: _content,
                ),
              ),
            );
          },
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _Encoding implements ComicArchiveFileNameEncodingRepository {
  @override
  Future<String?> load(String publicationId) async => null;
  @override
  Future<void> save(String publicationId, String? encodingName) async {}
  @override
  Future<void> delete(String publicationId) async {}
}
