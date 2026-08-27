import 'dart:async';

import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/reader/text_reader_session.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/reading_progress_repository.dart';
import 'package:fbooks/domain/reading/text_document.dart';
import 'package:fbooks/domain/reading/text_reading_preferences.dart';
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
    final preferences =
        ref.watch(textReadingPreferencesProvider).asData?.value ??
        TextReadingPreferences.defaults;
    return Scaffold(
      backgroundColor: _backgroundColor(preferences.appearance),
      appBar: AppBar(
        backgroundColor: _backgroundColor(preferences.appearance),
        foregroundColor: _foregroundColor(preferences.appearance),
        title: Text(title),
        centerTitle: MediaQuery.sizeOf(context).width < 720,
        actions: [
          IconButton(
            tooltip: 'Reading settings',
            onPressed: () => _showTextReadingSettings(context, ref),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: session.when(
        data: (value) => _TextChapterPager(
          publicationId: publicationId,
          session: value,
          preferences: preferences,
        ),
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
  const _TextChapterPager({
    required this.publicationId,
    required this.session,
    required this.preferences,
  });

  final PublicationId publicationId;
  final TextReaderSession session;
  final TextReadingPreferences preferences;

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
                preferences: widget.preferences,
              );
            },
          ),
        ),
        _TextChapterControls(
          currentChapter: _currentChapter,
          chapterCount: chapterCount,
          onChapterSelected: _goToChapter,
          appearance: widget.preferences.appearance,
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
    required this.appearance,
  });

  final int currentChapter;
  final int chapterCount;
  final ValueChanged<int> onChapterSelected;
  final TextReadingAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final canGoBack = currentChapter > 0;
    final canGoForward = currentChapter < chapterCount - 1;
    return SafeArea(
      top: false,
      child: Material(
        color: _controlsColor(appearance),
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
    required this.preferences,
  });

  final TextChapter chapter;
  final int initialOffset;
  final void Function(int chapterIndex, int offset) onPositionChanged;
  final TextReadingPreferences preferences;

  @override
  Widget build(BuildContext context) {
    return _TextChapterScrollView(
      chapter: chapter,
      initialOffset: initialOffset,
      onPositionChanged: onPositionChanged,
      preferences: preferences,
    );
  }
}

class _TextChapterScrollView extends StatefulWidget {
  const _TextChapterScrollView({
    required this.chapter,
    required this.initialOffset,
    required this.onPositionChanged,
    required this.preferences,
  });

  final TextChapter chapter;
  final int initialOffset;
  final void Function(int chapterIndex, int offset) onPositionChanged;
  final TextReadingPreferences preferences;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 840
            ? ((constraints.maxWidth - 720) / 2).clamp(
                widget.preferences.horizontalPadding,
                double.infinity,
              )
            : widget.preferences.horizontalPadding;
        return SelectionArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              32,
              horizontalPadding,
              48,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.chapter.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _foregroundColor(widget.preferences.appearance),
                  ),
                ),
                const SizedBox(height: 28),
                Text.rich(
                  TextSpan(
                    children: _chapterTextSpans(
                      context,
                      widget.chapter,
                      widget.preferences,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

List<InlineSpan> _chapterTextSpans(
  BuildContext context,
  TextChapter chapter,
  TextReadingPreferences preferences,
) {
  final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
    color: _foregroundColor(preferences.appearance),
    fontSize: preferences.fontSize,
    height: preferences.lineHeight,
  );
  final segments = chapter.segments.isEmpty
      ? [TextSegment(text: chapter.text)]
      : chapter.segments;
  return [
    for (final segment in segments)
      TextSpan(
        text: segment.text,
        style: segment.emphasized
            ? baseStyle?.copyWith(fontStyle: FontStyle.italic)
            : baseStyle,
      ),
  ];
}

Future<void> _showTextReadingSettings(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      var preferences =
          ref.read(textReadingPreferencesProvider).asData?.value ??
          TextReadingPreferences.defaults;
      return StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> update(TextReadingPreferences next) async {
            setModalState(() => preferences = next);
            await ref.read(textReadingPreferencesRepositoryProvider).save(next);
            ref.invalidate(textReadingPreferencesProvider);
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Text reading settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  _TextPreferenceSlider(
                    label: 'Text size',
                    valueLabel: '${preferences.fontSize.round()} pt',
                    value: preferences.fontSize,
                    min: 14,
                    max: 28,
                    divisions: 14,
                    onChanged: (value) =>
                        update(preferences.copyWith(fontSize: value)),
                  ),
                  const SizedBox(height: 12),
                  _TextPreferenceSlider(
                    label: 'Line height',
                    valueLabel: preferences.lineHeight.toStringAsFixed(1),
                    value: preferences.lineHeight,
                    min: 1.3,
                    max: 2.1,
                    divisions: 8,
                    onChanged: (value) =>
                        update(preferences.copyWith(lineHeight: value)),
                  ),
                  const SizedBox(height: 12),
                  _TextPreferenceSlider(
                    label: 'Page margins',
                    valueLabel: '${preferences.horizontalPadding.round()} px',
                    value: preferences.horizontalPadding,
                    min: 16,
                    max: 64,
                    divisions: 6,
                    onChanged: (value) =>
                        update(preferences.copyWith(horizontalPadding: value)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<TextReadingAppearance>(
                    segments: const [
                      ButtonSegment(
                        value: TextReadingAppearance.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: TextReadingAppearance.sepia,
                        icon: Icon(Icons.auto_stories_outlined),
                        label: Text('Sepia'),
                      ),
                      ButtonSegment(
                        value: TextReadingAppearance.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {preferences.appearance},
                    onSelectionChanged: (selection) => update(
                      preferences.copyWith(appearance: selection.single),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _TextPreferenceSlider extends StatelessWidget {
  const _TextPreferenceSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          Text(valueLabel),
        ],
      ),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: valueLabel,
        onChanged: onChanged,
      ),
    ],
  );
}

Color _backgroundColor(TextReadingAppearance appearance) =>
    switch (appearance) {
      TextReadingAppearance.light => const Color(0xFFF8F7F3),
      TextReadingAppearance.dark => const Color(0xFF1C1D20),
      TextReadingAppearance.sepia => const Color(0xFFF3E7CD),
    };

Color _foregroundColor(TextReadingAppearance appearance) =>
    switch (appearance) {
      TextReadingAppearance.light ||
      TextReadingAppearance.sepia => const Color(0xFF1C1D20),
      TextReadingAppearance.dark => const Color(0xFFF6F3EC),
    };

Color _controlsColor(TextReadingAppearance appearance) => switch (appearance) {
  TextReadingAppearance.light => const Color(0xFFEAE8E2),
  TextReadingAppearance.dark => const Color(0xFF292A2D),
  TextReadingAppearance.sepia => const Color(0xFFE4D3B2),
};
