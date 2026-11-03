import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fbooks/features/reader/presentation/page_curl/page_curl_viewport.dart';

import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/text_reading_preferences.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

typedef FlowPagePreview = Widget Function(VoidCallback onReady);

class FlowPagination {
  const FlowPagination({
    required this.pageIndex,
    required this.pageCount,
    required this.canGoBack,
    required this.canGoForward,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSelected,
  });

  final int pageIndex;
  final int pageCount;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final ValueChanged<int> onPageSelected;
}

/// Paginates the laid-out content, preserving the same renderer in both modes.
class FlowContentViewport extends StatefulWidget {
  const FlowContentViewport({
    super.key,
    required this.position,
    required this.mode,
    required this.onPositionChanged,
    required this.child,
    this.onPreviousChapter,
    this.onNextChapter,
    this.controlsBuilder,
    this.onPaginationChanged,
    this.pagePadding = EdgeInsets.zero,
    this.paperColor = Colors.white,
    this.contentRevision = 0,
    this.prepareChapter,
    this.previewOnly = false,
  });

  final TextOffsetLocator position;
  final TextReadingMode mode;
  final ValueChanged<TextOffsetLocator> onPositionChanged;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;
  final Widget child;
  final EdgeInsets pagePadding;
  final Color paperColor;
  final Object contentRevision;
  final Future<FlowPagePreview?> Function(int direction)? prepareChapter;
  final bool previewOnly;
  final Widget Function(BuildContext context, FlowPagination pagination)?
  controlsBuilder;
  final ValueChanged<FlowPagination>? onPaginationChanged;

  @override
  State<FlowContentViewport> createState() => _FlowContentViewportState();
}

class _FlowContentViewportState extends State<FlowContentViewport> {
  final _contentKey = GlobalKey();
  final _scroll = ScrollController();
  late TextOffsetLocator _position = widget.position;
  List<double> _breaks = [0, 1];
  List<RenderParagraph> _paragraphs = [];
  double _height = 1;
  int _page = 0;
  bool _measuring = false;
  bool _scheduled = false;
  bool _ready = false;
  int _revision = 0;
  Size _pageSize = Size.zero;
  FlowPagePreview? _preview;
  Completer<void>? _previewReady;
  final _previewKey = GlobalKey();

  bool get _paged => widget.mode == TextReadingMode.paged;
  RenderBox? get _content =>
      _contentKey.currentContext?.findRenderObject() as RenderBox?;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_scrolled);
  }

  @override
  void didUpdateWidget(covariant FlowContentViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父组件重建时可能创建等值 locator；只有位置内容变化才是跳转请求。
    if (!_samePosition(oldWidget.position, widget.position) &&
        !_samePosition(widget.position, _position)) {
      _position = widget.position;
      _revision++;
      _clearPreview();
    }
    if (oldWidget.contentRevision != widget.contentRevision ||
        oldWidget.mode != widget.mode ||
        oldWidget.paperColor != widget.paperColor) {
      _revision++;
      _clearPreview();
    }
    _scheduleMeasure();
  }

  void _clearPreview() {
    _preview = null;
    final pending = _previewReady;
    _previewReady = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  @override
  void dispose() {
    _revision++;
    _clearPreview();
    _scroll.dispose();
    super.dispose();
  }

  void _scheduleMeasure() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _measure();
    });
  }

  void _measure() {
    final content = _content;
    if (content == null || !content.hasSize || !_scroll.hasClients) return;
    _measuring = true;
    final intervals = <({double top, double bottom})>[];
    _paragraphs = [];
    void visit(RenderObject object) {
      if (object is RenderParagraph && object.hasSize) {
        if (object.text.toPlainText().replaceAll('￼', '').trim().isNotEmpty) {
          _paragraphs.add(object);
        }
        final origin = object.localToGlobal(Offset.zero, ancestor: content);
        var textOffset = 0;
        void collect(InlineSpan span) {
          if (span is TextSpan) {
            final length = span.text?.length ?? 0;
            if (length > 0) {
              for (final box in object.getBoxesForSelection(
                TextSelection(
                  baseOffset: textOffset,
                  extentOffset: textOffset + length,
                ),
              )) {
                intervals.add((
                  top: origin.dy + box.top,
                  bottom: origin.dy + box.bottom,
                ));
              }
            }
            textOffset += length;
            for (final child in span.children ?? <InlineSpan>[]) {
              collect(child);
            }
          } else if (span is PlaceholderSpan) {
            textOffset++;
          }
        }

        collect(object.text);
      } else if (object is RenderImage && object.hasSize) {
        final top = object.localToGlobal(Offset.zero, ancestor: content).dy;
        intervals.add((top: top, bottom: top + object.size.height));
      }
      object.visitChildren(visit);
    }

    visit(content);
    intervals.sort((a, b) => a.top.compareTo(b.top));
    // Merge overlapping boxes (including bidi runs and adjacent table cells).
    final spans = <({double top, double bottom})>[];
    for (final interval in intervals) {
      if (spans.isNotEmpty && interval.top < spans.last.bottom - 0.01) {
        final previous = spans.removeLast();
        spans.add((
          top: previous.top,
          bottom: math.max(previous.bottom, interval.bottom),
        ));
      } else {
        spans.add(interval);
      }
    }
    final breaks = <double>[0];
    var cursor = 0;
    while (breaks.last + _height < content.size.height - 0.01) {
      final start = breaks.last;
      var end = start + _height;
      while (cursor < spans.length && spans[cursor].bottom <= end + 0.01) {
        cursor++;
      }
      if (cursor < spans.length &&
          spans[cursor].top < end &&
          spans[cursor].top > start + 0.01) {
        end = spans[cursor].top;
      }
      // Oversized indivisible content remains reachable on successive pages.
      breaks.add(end);
    }
    breaks.add(math.max(content.size.height, breaks.last + 1));
    if (_breaks.length != breaks.length ||
        Iterable.generate(breaks.length).any((i) => _breaks[i] != breaks[i])) {
      _revision++;
      _clearPreview();
    }
    _breaks = breaks;
    var offset = _position.offset.toDouble();
    final paragraphIndex = _position.paragraphIndex;
    if (paragraphIndex != null && paragraphIndex < _paragraphs.length) {
      final paragraph = _paragraphs[paragraphIndex];
      final character = _position.characterOffset!.clamp(
        0,
        paragraph.text.toPlainText().length,
      );
      offset = paragraph
          .localToGlobal(
            paragraph.getOffsetForCaret(
              TextPosition(offset: character),
              Rect.zero,
            ),
            ancestor: content,
          )
          .dy;
      if (_paged) {
        offset +=
            paragraph.getFullHeightForCaret(TextPosition(offset: character)) /
            2;
      }
    }
    _page = _pageFor(offset);
    final target = _paged ? _breaks[_page] : offset;
    _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
    _ready = true;
    _measuring = false;
    setState(() {});
    _reportPosition(preserveAnchor: paragraphIndex != null);
    _reportPagination();
  }

  int _pageFor(double offset) {
    var low = 0;
    var high = _breaks.length - 2;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (_breaks[middle] <= offset + 0.01) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }

  void _scrolled() {
    if (_measuring || !_ready) return;
    _reportPosition();
  }

  void _reportPosition({bool preserveAnchor = false}) {
    final content = _content;
    if (content == null || !_scroll.hasClients) return;
    final offset = _scroll.offset;
    int? paragraphIndex;
    int? characterOffset;
    for (var i = 0; i < _paragraphs.length; i++) {
      final paragraph = _paragraphs[i];
      final top = paragraph.localToGlobal(Offset.zero, ancestor: content).dy;
      if (top + paragraph.size.height <= offset) continue;
      paragraphIndex = i;
      characterOffset = paragraph
          .getPositionForOffset(Offset(0, math.max(0, offset - top) + 0.1))
          .offset;
      break;
    }
    _position = TextOffsetLocator(
      chapterIndex: widget.position.chapterIndex,
      offset: offset.round().clamp(0, 1 << 31),
      paragraphIndex: preserveAnchor
          ? _position.paragraphIndex
          : paragraphIndex,
      characterOffset: preserveAnchor
          ? _position.characterOffset
          : characterOffset,
    );
    widget.onPositionChanged(_position);
  }

  // 直接截取内容层中的页区间，不滚动正文，也不生成整章的大纹理。
  ui.Image _capturePage(int page) {
    final content = _content as _RenderPageContentBoundary;
    final padding = widget.pagePadding;
    final ratio = _textureRatio;
    final height = math.min(_height, _breaks[page + 1] - _breaks[page]);
    final image = content.capture(
      Rect.fromLTWH(0, _breaks[page], content.size.width, height),
      pixelRatio: ratio,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);
    canvas.drawRect(
      Offset.zero & _pageSize,
      Paint()..color = widget.paperColor,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(padding.left, padding.top, content.size.width, height),
      Paint(),
    );
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(
        (_pageSize.width * ratio).ceil(),
        (_pageSize.height * ratio).ceil(),
      );
    } finally {
      picture.dispose();
      image.dispose();
    }
  }

  // 两张页面最多约 32 MiB RGBA；大桌面窗口也不按整章高度分配。
  double get _textureRatio => math.min(
    MediaQuery.devicePixelRatioOf(context),
    math.min(
      4096 / math.max(_pageSize.width, _pageSize.height),
      math.sqrt(4 * 1024 * 1024 / (_pageSize.width * _pageSize.height)),
    ),
  );

  Future<CurlTurnPages?> _prepareTurn(int direction) async {
    if (!_ready) return null;
    final page = _page + direction;
    final chapterTurn = page < 0 || page >= _breaks.length - 1;
    if (chapterTurn &&
        (widget.prepareChapter == null ||
            (direction < 0 ? widget.onPreviousChapter : widget.onNextChapter) ==
                null)) {
      return null;
    }
    final revision = _revision;
    final sourcePage = _page;
    ui.Image? current, target;
    try {
      if (!chapterTurn) {
        current = _capturePage(_page);
        target = _capturePage(page);
      } else {
        final builder = await widget.prepareChapter!(direction);
        if (!mounted ||
            revision != _revision ||
            sourcePage != _page ||
            builder == null) {
          return null;
        }
        final ready = Completer<void>();
        setState(() {
          _preview = builder;
          _previewReady = ready;
        });
        await ready.future;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || revision != _revision || sourcePage != _page) {
          return null;
        }
        current = _capturePage(_page);
        final boundary =
            _previewKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        target = boundary.toImageSync(pixelRatio: _textureRatio);
      }
      final result = CurlTurnPages(current: current, target: target);
      current = target = null;
      return result;
    } finally {
      current?.dispose();
      target?.dispose();
      if (mounted && revision == _revision && _preview != null) {
        setState(_clearPreview);
      }
    }
  }

  void _turn(int delta) {
    if (!_ready) return;
    final next = _page + delta;
    _revision++;
    _clearPreview();
    if (next < 0) {
      widget.onPreviousChapter?.call();
    } else if (next >= _breaks.length - 1) {
      widget.onNextChapter?.call();
    } else {
      setState(() => _page = next);
      _scroll.jumpTo(_breaks[_page]);
      _reportPagination();
    }
  }

  FlowPagination get _pagination => FlowPagination(
    pageIndex: _page,
    pageCount: _breaks.length - 1,
    canGoBack: _page > 0 || widget.onPreviousChapter != null,
    canGoForward: _page < _breaks.length - 2 || widget.onNextChapter != null,
    onPreviousPage: () => _turn(-1),
    onNextPage: () => _turn(1),
    onPageSelected: (index) {
      if (!_ready) return;
      _revision++;
      _clearPreview();
      setState(() => _page = index.clamp(0, _breaks.length - 2));
      _scroll.jumpTo(_breaks[_page]);
      _reportPagination();
    },
  );

  void _reportPagination() {
    if (widget.onPaginationChanged == null) return;
    final pagination = _pagination;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPaginationChanged?.call(pagination);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final padding = widget.pagePadding;
              final size = constraints.biggest;
              final height = math.max(1.0, size.height - padding.vertical);
              if (_pageSize != size) {
                _revision++;
                _clearPreview();
                _pageSize = size;
                _scheduleMeasure();
              }
              if (_height != height) {
                _height = height;
                _scheduleMeasure();
              }
              final visibleHeight = _paged && _ready
                  ? math.min(_height, _breaks[_page + 1] - _breaks[_page])
                  : _height;
              Widget viewport = ClipRect(
                clipper: _PageClipper(visibleHeight),
                child: SingleChildScrollView(
                  key: const Key('flow-content-scroll'),
                  controller: _scroll,
                  physics: _paged ? const NeverScrollableScrollPhysics() : null,
                  // Allow the final page to start at its own boundary.
                  padding: EdgeInsets.only(bottom: _paged ? _height : 0),
                  child: NotificationListener<SizeChangedLayoutNotification>(
                    onNotification: (_) {
                      _scheduleMeasure();
                      return true;
                    },
                    child: SizeChangedLayoutNotifier(
                      child: _PageContentBoundary(
                        key: _contentKey,
                        child: SizedBox(
                          width: math.max(
                            1,
                            constraints.maxWidth - padding.horizontal,
                          ),
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              viewport = ColoredBox(
                color: widget.paperColor,
                child: Padding(padding: padding, child: viewport),
              );
              if (_paged) {
                if (!widget.previewOnly) {
                  viewport = PageCurlViewport(
                    revision: (_revision, _page, widget.paperColor),
                    paperColor: widget.paperColor,
                    prepareTurn: _prepareTurn,
                    onTurn: _turn,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_preview case final builder?)
                          IgnorePointer(
                            child: ExcludeSemantics(
                              child: RepaintBoundary(
                                key: _previewKey,
                                child: ExcludeFocus(
                                  child: builder(() {
                                    final ready = _previewReady;
                                    if (ready != null && !ready.isCompleted) {
                                      ready.complete();
                                    }
                                  }),
                                ),
                              ),
                            ),
                          ),
                        viewport,
                      ],
                    ),
                  );
                }
                viewport = CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                        _turn(1),
                    const SingleActivator(LogicalKeyboardKey.pageDown): () =>
                        _turn(1),
                    const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                        _turn(-1),
                    const SingleActivator(LogicalKeyboardKey.pageUp): () =>
                        _turn(-1),
                  },
                  child: Focus(autofocus: true, child: viewport),
                );
              }
              return SelectionArea(child: viewport);
            },
          ),
        ),
        if (_paged)
          if (widget.controlsBuilder != null)
            widget.controlsBuilder!(context, _pagination)
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: AppLocalizations.of(context).previousPage,
                  onPressed: _page > 0 || widget.onPreviousChapter != null
                      ? () => _turn(-1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  AppLocalizations.of(context)
                      .pageProgress(_page + 1, _breaks.length - 1),
                  key: const Key('flow-page-progress'),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).nextPage,
                  onPressed:
                      _page < _breaks.length - 2 || widget.onNextChapter != null
                      ? () => _turn(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
      ],
    );
  }
}

bool _samePosition(TextOffsetLocator a, TextOffsetLocator b) =>
    a.chapterIndex == b.chapterIndex &&
    a.offset == b.offset &&
    a.paragraphIndex == b.paragraphIndex &&
    a.characterOffset == b.characterOffset;

class _PageClipper extends CustomClipper<Rect> {
  const _PageClipper(this.height);
  final double height;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, height);

  @override
  bool shouldReclip(_PageClipper oldClipper) => oldClipper.height != height;
}

// 在 RenderObject 内访问合成层，只允许按当前页区域截图。
class _PageContentBoundary extends SingleChildRenderObjectWidget {
  const _PageContentBoundary({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPageContentBoundary();
}

class _RenderPageContentBoundary extends RenderRepaintBoundary {
  ui.Image capture(Rect bounds, {required double pixelRatio}) {
    assert(!debugNeedsPaint);
    return (layer! as OffsetLayer).toImageSync(bounds, pixelRatio: pixelRatio);
  }
}
