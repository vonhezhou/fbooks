import 'dart:async';

import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/reader/text_reader_session.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/reading_progress_repository.dart';
import 'package:fbooks/domain/reading/text_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TextReaderPage extends ConsumerWidget {
  const TextReaderPage({
    super.key,
    required this.publicationId,
    required this.title,
  });

  final PublicationId publicationId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(textReaderSessionProvider(publicationId));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: session.when(
        data: (value) =>
            _TextChapterPager(publicationId: publicationId, session: value),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to open this publication.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _TextChapterPager extends ConsumerStatefulWidget {
  const _TextChapterPager({required this.publicationId, required this.session});

  final PublicationId publicationId;
  final TextReaderSession session;

  @override
  ConsumerState<_TextChapterPager> createState() => _TextChapterPagerState();
}

class _TextChapterPagerState extends ConsumerState<_TextChapterPager> {
  late final PageController _pageController;
  late final ReadingProgressRepository _progressRepository;
  bool _hasRestoredPosition = false;
  var _currentChapter = 0;
  final _chapterOffsets = <int, int>{};
  Timer? _pendingProgressWrite;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressRepository = ref.read(readingProgressRepositoryProvider);
  }

  @override
  void dispose() {
    _pendingProgressWrite?.cancel();
    final offset = _chapterOffsets[_currentChapter] ?? 0;
    unawaited(_persistPosition(_currentChapter, offset));
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref
        .watch(readingProgressProvider(widget.publicationId))
        .whenData(_restorePosition);
    final chapterCount = widget.session.document.chapters.length;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: chapterCount,
            onPageChanged: _savePosition,
            itemBuilder: (context, index) {
              return _TextChapterView(
                key: ValueKey(widget.session.document.chapters[index].index),
                chapter: widget.session.document.chapters[index],
                initialOffset: _chapterOffsets[index] ?? 0,
                onPositionChanged: _savePosition,
              );
            },
          ),
        ),
        _TextChapterControls(
          currentChapter: _currentChapter,
          chapterCount: chapterCount,
          onChapterSelected: _goToChapter,
        ),
      ],
    );
  }

  void _restorePosition(ReadingProgress? progress) {
    if (_hasRestoredPosition) {
      return;
    }
    _hasRestoredPosition = true;
    final locator = progress?.locator;
    if (locator is! TextOffsetLocator) {
      return;
    }
    final lastChapter = widget.session.document.chapters.length - 1;
    final chapterIndex = locator.chapterIndex.clamp(0, lastChapter).toInt();
    _chapterOffsets[chapterIndex] = locator.offset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(chapterIndex);
        setState(() => _currentChapter = chapterIndex);
      }
    });
  }

  void _savePosition(int chapterIndex, [int offset = 0]) {
    if (_currentChapter != chapterIndex) {
      setState(() => _currentChapter = chapterIndex);
    }
    _chapterOffsets[chapterIndex] = offset;
    _queuePositionPersist(chapterIndex, offset);
  }

  Future<void> _goToChapter(int chapterIndex) async {
    if (!_pageController.hasClients || chapterIndex == _currentChapter) {
      return;
    }
    await _pageController.animateToPage(
      chapterIndex,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _queuePositionPersist(int chapterIndex, int offset) {
    _pendingProgressWrite?.cancel();
    _pendingProgressWrite = Timer(const Duration(milliseconds: 400), () {
      unawaited(_persistPosition(chapterIndex, offset));
    });
  }

  Future<void> _persistPosition(int chapterIndex, [int offset = 0]) async {
    try {
      await _progressRepository.save(
        ReadingProgress(
          publicationId: widget.publicationId,
          locator: TextOffsetLocator(
            chapterIndex: chapterIndex,
            offset: offset,
          ),
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // A failed progress write must not interrupt reading.
    }
  }
}

class _TextChapterControls extends StatelessWidget {
  const _TextChapterControls({
    required this.currentChapter,
    required this.chapterCount,
    required this.onChapterSelected,
  });

  final int currentChapter;
  final int chapterCount;
  final ValueChanged<int> onChapterSelected;

  @override
  Widget build(BuildContext context) {
    final canGoBack = currentChapter > 0;
    final canGoForward = currentChapter < chapterCount - 1;
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous chapter',
                onPressed: canGoBack
                    ? () => onChapterSelected(currentChapter - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Slider(
                  value: currentChapter.toDouble(),
                  min: 0,
                  max: (chapterCount - 1).toDouble(),
                  divisions: chapterCount > 1 ? chapterCount - 1 : null,
                  label: 'Chapter ${currentChapter + 1} of $chapterCount',
                  onChanged: chapterCount > 1
                      ? (value) => onChapterSelected(value.round())
                      : null,
                ),
              ),
              Text('${currentChapter + 1} / $chapterCount'),
              IconButton(
                tooltip: 'Next chapter',
                onPressed: canGoForward
                    ? () => onChapterSelected(currentChapter + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextChapterView extends StatelessWidget {
  const _TextChapterView({
    super.key,
    required this.chapter,
    required this.initialOffset,
    required this.onPositionChanged,
  });

  final TextChapter chapter;
  final int initialOffset;
  final void Function(int chapterIndex, int offset) onPositionChanged;

  @override
  Widget build(BuildContext context) {
    return _TextChapterScrollView(
      chapter: chapter,
      initialOffset: initialOffset,
      onPositionChanged: onPositionChanged,
    );
  }
}

class _TextChapterScrollView extends StatefulWidget {
  const _TextChapterScrollView({
    required this.chapter,
    required this.initialOffset,
    required this.onPositionChanged,
  });

  final TextChapter chapter;
  final int initialOffset;
  final void Function(int chapterIndex, int offset) onPositionChanged;

  @override
  State<_TextChapterScrollView> createState() => _TextChapterScrollViewState();
}

class _TextChapterScrollViewState extends State<_TextChapterScrollView> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: widget.initialOffset.toDouble(),
    )..addListener(_reportPosition);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_reportPosition)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _TextChapterScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialOffset == widget.initialOffset ||
        !_scrollController.hasClients) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(widget.initialOffset.toDouble());
      }
    });
  }

  void _reportPosition() {
    widget.onPositionChanged(
      widget.chapter.index,
      _scrollController.offset.round().clamp(0, 1 << 31).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.chapter.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Text(
              widget.chapter.text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
