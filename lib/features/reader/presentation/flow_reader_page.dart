import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:fbooks/app/providers.dart';
import 'package:fbooks/features/reader/presentation/reader_chrome.dart';
import 'package:fbooks/application/reader/flow_reading_session.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/reading_progress_repository.dart';
import 'package:fbooks/domain/reading/flow_document.dart';
import 'package:fbooks/domain/reading/text_reading_preferences.dart';
import 'package:fbooks/features/reader/presentation/reader_settings_surface.dart';
import 'package:fbooks/features/reader/presentation/flow_content_viewport.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlowReaderPage extends ConsumerWidget {
  const FlowReaderPage({
    super.key,
    required this.publicationId,
    required this.title,
  });

  final PublicationId publicationId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 960;
      final session = ref.watch(flowReadingSessionProvider(publicationId));
      final preferences =
          ref.watch(textReadingPreferencesProvider).asData?.value ??
          TextReadingPreferences.defaults;
      return Theme(
        data: _textReaderTheme(preferences.appearance),
        child: Builder(
          builder: (context) {
            void showSettings() =>
                _showTextReadingSettings(context, ref, desktop: desktop);
            return session.when(
              data: (value) => _FlowChapterPager(
                key: ObjectKey(value),
                publicationId: publicationId,
                title: title,
                session: value,
                preferences: preferences,
                desktop: desktop,
                onShowSettings: showSettings,
              ),
              error: (error, stackTrace) => _FlowReaderFrame(
                title: title,
                onShowSettings: showSettings,
                appearance: preferences.appearance,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      AppLocalizations.of(context)
                          .unableToOpenPublication(error.toString()),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              loading: () => _FlowReaderFrame(
                title: title,
                onShowSettings: showSettings,
                appearance: preferences.appearance,
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
          },
        ),
      );
    },
  );
}

class _FlowReaderFrame extends StatelessWidget {
  const _FlowReaderFrame({
    required this.title,
    required this.onShowSettings,
    required this.appearance,
    required this.child,
    this.leadingActions = const [],
    this.progress,
  });

  final String title;
  final VoidCallback onShowSettings;
  final TextReadingAppearance appearance;
  final Widget child;
  final List<Widget> leadingActions;
  final Widget? progress;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _backgroundColor(appearance),
    body: Column(
      children: [
        ReaderToolbar(
          title: title,
          height: MediaQuery.sizeOf(context).width < 600 ? 56 : 64,
          leadingActions: leadingActions,
          progress: progress,
          actions: [
            const ReaderFullscreenButton(),
            IconButton(
              tooltip: AppLocalizations.of(context).readingSettings,
              onPressed: onShowSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        Expanded(child: child),
      ],
    ),
  );
}

class _FlowChapterPager extends ConsumerStatefulWidget {
  const _FlowChapterPager({
    super.key,
    required this.publicationId,
    required this.title,
    required this.session,
    required this.preferences,
    required this.desktop,
    required this.onShowSettings,
  });

  final PublicationId publicationId;
  final String title;
  final FlowReadingSession session;
  final TextReadingPreferences preferences;
  final bool desktop;
  final VoidCallback onShowSettings;

  @override
  ConsumerState<_FlowChapterPager> createState() => _FlowChapterPagerState();
}

class _FlowChapterPagerState extends ConsumerState<_FlowChapterPager> {
  late final ReadingProgressRepository _progressRepository;
  bool _hasRestoredPosition = false;
  var _currentChapter = 0;
  final _chapterPositions = <int, TextOffsetLocator>{};
  Timer? _pendingProgressWrite;
  var _outlineVisible = true;
  final _pagination = ValueNotifier<FlowPagination?>(null);
  final _loadedChapters = <int, FlowChapter>{};
  final _chapterSnapshots = <int, FlowPageSnapshotController>{};

  Future<FlowChapter> _loadChapter(int index) async {
    final chapter = await widget.session.loadChapter(index);
    _loadedChapters[index] = chapter;
    return chapter;
  }

  @override
  void initState() {
    super.initState();
    _progressRepository = ref.read(readingProgressRepositoryProvider);
  }

  @override
  void dispose() {
    _pendingProgressWrite?.cancel();
    final position = _chapterPositions[_currentChapter];
    if (position != null) unawaited(_persistPosition(position));
    _pagination.dispose();
    super.dispose();
  }

  List<FlowTableOfContentsEntry> get _tableOfContents =>
      widget.session.document.tableOfContents.isNotEmpty
      ? widget.session.document.tableOfContents
      : [
          for (final chapter in widget.session.document.chapters)
            FlowTableOfContentsEntry(
              title: chapter.title,
              chapterIndex: chapter.index,
            ),
        ];

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(readingProgressProvider(widget.publicationId));
    final l10n = AppLocalizations.of(context);
    final chapterCount = widget.session.document.chapters.length;
    final chapterLabel = l10n.chapterProgress(
      _currentChapter + 1,
      chapterCount,
    );
    return _FlowReaderFrame(
      title: widget.title,
      appearance: widget.preferences.appearance,
      onShowSettings: widget.onShowSettings,
      leadingActions: [
        if (chapterCount > 0)
          IconButton(
            tooltip: l10n.tableOfContents,
            onPressed: () {
              if (widget.desktop) {
                setState(() => _outlineVisible = !_outlineVisible);
              } else {
                _showTableOfContents(
                  context,
                  _tableOfContents,
                  _goToChapter,
                  appearance: widget.preferences.appearance,
                  currentChapter: _currentChapter,
                  chapterCount: chapterCount,
                );
              }
            },
            icon: const Icon(Icons.menu),
          ),
      ],
      progress: chapterCount > 0
          ? ValueListenableBuilder<FlowPagination?>(
              valueListenable: _pagination,
              builder: (context, pagination, _) => Text(
                !widget.desktop ||
                        pagination == null ||
                        widget.preferences.mode == TextReadingMode.scroll
                    ? chapterLabel
                    : '$chapterLabel · ${l10n.pageProgress(pagination.pageIndex + 1, pagination.pageCount)}',
                key: const Key('text-reader-position'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          : null,
      child: !_hasRestoredPosition && progress.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildReader(context, progress, chapterCount),
    );
  }

  Widget _buildReader(
    BuildContext context,
    AsyncValue<ReadingProgress?> progress,
    int chapterCount,
  ) {
    progress.whenData(_restorePosition);
    if (chapterCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.article_outlined, size: 52),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context).readerEmptyTitle),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).readerEmptyDescription,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.desktop && _outlineVisible)
                SizedBox(
                  key: const Key('text-reader-desktop-table-of-contents'),
                  width: 320,
                  child: _TableOfContentsPanel(
                    entries: _tableOfContents,
                    currentChapter: _currentChapter,
                    chapterCount: chapterCount,
                    onSelected: _goToChapter,
                    appearance: widget.preferences.appearance,
                    onClose: () => setState(() => _outlineVisible = false),
                  ),
                ),
              Expanded(
                key: const Key('text-reader-content'),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 仅保留当前及相邻章节的排版；背景章绘制在不透明正文下方。
                    for (final index in [
                      if (widget.preferences.mode == TextReadingMode.paged &&
                          _currentChapter > 0)
                        _currentChapter - 1,
                      if (widget.preferences.mode == TextReadingMode.paged &&
                          _currentChapter + 1 < chapterCount)
                        _currentChapter + 1,
                      _currentChapter,
                    ])
                      IgnorePointer(
                        key: ValueKey(
                          widget.session.document.chapters[index].index,
                        ),
                        ignoring: index != _currentChapter,
                        child: ExcludeFocus(
                          excluding: index != _currentChapter,
                          child: ExcludeSemantics(
                            excluding: index != _currentChapter,
                            child: _DeferredFlowChapterView(
                              previewOnly: index != _currentChapter,
                              snapshotController: _chapterSnapshots.putIfAbsent(
                                index,
                                FlowPageSnapshotController.new,
                              ),
                              captureChapterPage: (direction) =>
                                  _chapterSnapshots
                                      .putIfAbsent(
                                        index + direction,
                                        FlowPageSnapshotController.new,
                                      )
                                      .captureBoundary(fromEnd: direction < 0),
                              loadChapter: () => _loadChapter(index),
                              initialChapter: _loadedChapters[index],
                              loadAdjacentChapter: (direction) =>
                                  _loadChapter(index + direction),
                              initialPosition:
                                  _chapterPositions[index] ??
                                  TextOffsetLocator(
                                    chapterIndex: index,
                                    offset: 0,
                                  ),
                              onPreviousChapter: index > 0
                                  ? () => _goToChapter(index - 1, fromEnd: true)
                                  : null,
                              onNextChapter: index < chapterCount - 1
                                  ? () =>
                                        _goToChapter(index + 1, fromStart: true)
                                  : null,
                              onPositionChanged: _savePosition,
                              onChapterSelected: _goToChapter,
                              onPaginationChanged: (value) {
                                if (index == _currentChapter && mounted) {
                                  final previous = _pagination.value;
                                  if (previous?.pageIndex != value.pageIndex ||
                                      previous?.pageCount != value.pageCount ||
                                      previous?.canGoBack != value.canGoBack ||
                                      previous?.canGoForward !=
                                          value.canGoForward) {
                                    _pagination.value = value;
                                  }
                                }
                              },
                              preferences: widget.preferences,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 页码通知只重建控制区，不重建或重新布局整章正文。
        ValueListenableBuilder<FlowPagination?>(
          valueListenable: _pagination,
          builder: (context, pagination, _) => _FlowReaderControls(
            key: widget.desktop
                ? const Key('text-reader-desktop-controls')
                : const Key('text-reader-compact-controls'),
            pagination: widget.preferences.mode == TextReadingMode.paged
                ? pagination
                : null,
            paged: widget.preferences.mode == TextReadingMode.paged,
            currentChapter: _currentChapter,
            chapterCount: chapterCount,
            onChapterSelected: _goToChapter,
          ),
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
    if (lastChapter < 0) return;
    final chapterIndex = locator.chapterIndex.clamp(0, lastChapter).toInt();
    _chapterPositions[chapterIndex] = TextOffsetLocator(
      chapterIndex: chapterIndex,
      offset: locator.offset,
      paragraphIndex: locator.paragraphIndex,
      characterOffset: locator.characterOffset,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _currentChapter = chapterIndex);
    });
  }

  void _savePosition(TextOffsetLocator position) {
    // 背景章准备首／末页是临时预览，取消后不得改变该章的恢复锚点。
    if (position.chapterIndex != _currentChapter) return;
    _chapterPositions[position.chapterIndex] = position;
    _queuePositionPersist(position);
  }

  Future<void> _goToChapter(
    int chapterIndex, {
    bool fromEnd = false,
    bool fromStart = false,
  }) async {
    if (chapterIndex == _currentChapter) {
      return;
    }
    if (fromEnd || fromStart) {
      _chapterPositions[chapterIndex] = TextOffsetLocator(
        chapterIndex: chapterIndex,
        offset: fromEnd ? 1 << 31 : 0,
      );
    }
    setState(() {
      _currentChapter = chapterIndex;
      _pagination.value = null;
    });
  }

  void _queuePositionPersist(TextOffsetLocator position) {
    _pendingProgressWrite?.cancel();
    _pendingProgressWrite = Timer(const Duration(milliseconds: 400), () {
      unawaited(_persistPosition(position));
    });
  }

  Future<void> _persistPosition(TextOffsetLocator position) async {
    try {
      await _progressRepository.save(
        ReadingProgress(
          publicationId: widget.publicationId,
          locator: position,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // A failed progress write must not interrupt reading.
    }
  }
}

class _FlowReaderControls extends StatelessWidget {
  const _FlowReaderControls({
    super.key,
    required this.pagination,
    required this.paged,
    required this.currentChapter,
    required this.chapterCount,
    required this.onChapterSelected,
  });

  final FlowPagination? pagination;
  final bool paged;
  final int currentChapter;
  final int chapterCount;
  final ValueChanged<int> onChapterSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pagination = this.pagination;
    if (paged) {
      // 占位与真实控件共用同一布局，避免章节交接时改变正文高度并重排长章。
      return Visibility(
        visible: pagination != null,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: ReaderPageNavigation(
          currentPage: pagination == null ? 1 : pagination.pageIndex + 1,
          pageCount: pagination?.pageCount ?? 1,
          onPrevious: pagination?.canGoBack == true
              ? pagination!.onPreviousPage
              : null,
          onNext: pagination?.canGoForward == true
              ? pagination!.onNextPage
              : null,
          onPageSelected: (page) => pagination?.onPageSelected(page - 1),
        ),
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.previousChapter,
                    onPressed: currentChapter > 0
                        ? () => onChapterSelected(currentChapter - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      l10n.chapterProgress(currentChapter + 1, chapterCount),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.nextChapter,
                    onPressed: currentChapter < chapterCount - 1
                        ? () => onChapterSelected(currentChapter + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showTableOfContents(
  BuildContext context,
  List<FlowTableOfContentsEntry> entries,
  ValueChanged<int> onSelected, {
  required TextReadingAppearance appearance,
  required int currentChapter,
  required int chapterCount,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog.fullscreen(
    child: _TableOfContentsPanel(
      entries: entries,
      currentChapter: currentChapter,
      chapterCount: chapterCount,
      onSelected: (index) {
        Navigator.of(context).pop();
        onSelected(index);
      },
      onClose: () => Navigator.of(context).pop(),
      appearance: appearance,
    ),
  ),
);

class _TableOfContentsPanel extends StatelessWidget {
  const _TableOfContentsPanel({
    required this.entries,
    required this.currentChapter,
    required this.chapterCount,
    required this.onSelected,
    required this.onClose,
    required this.appearance,
  });

  final List<FlowTableOfContentsEntry> entries;
  final int currentChapter;
  final int chapterCount;
  final ValueChanged<int> onSelected;
  final VoidCallback onClose;
  final TextReadingAppearance appearance;

  @override
  Widget build(BuildContext context) => Theme(
    data: _textReaderTheme(appearance),
    child: Builder(
      builder: (context) => Material(
        key: const Key('text-reader-table-of-contents-surface'),
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).tableOfContents,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: AppLocalizations.of(context)
                            .closeTableOfContents,
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        key: Key('text-reader-toc-$index'),
                        selected: entry.chapterIndex == currentChapter,
                        selectedTileColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: .4),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 4,
                        ),
                        title: Text(entry.title),
                        subtitle: Text(
                          AppLocalizations.of(context).chapterProgress(
                            entry.chapterIndex + 1,
                            chapterCount,
                          ),
                        ),
                        onTap: () => onSelected(entry.chapterIndex),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DeferredFlowChapterView extends StatefulWidget {
  const _DeferredFlowChapterView({
    required this.loadChapter,
    this.initialChapter,
    this.previewOnly = false,
    this.snapshotController,
    this.captureChapterPage,
    required this.initialPosition,
    this.loadAdjacentChapter,
    this.onPreviousChapter,
    this.onNextChapter,
    required this.onPositionChanged,
    required this.onChapterSelected,
    required this.preferences,
    required this.onPaginationChanged,
  });

  final Future<FlowChapter> Function() loadChapter;
  final FlowChapter? initialChapter;
  final bool previewOnly;
  final FlowPageSnapshotController? snapshotController;
  final Future<ui.Image?> Function(int direction)? captureChapterPage;
  final TextOffsetLocator initialPosition;
  final Future<FlowChapter> Function(int direction)? loadAdjacentChapter;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;
  final ValueChanged<TextOffsetLocator> onPositionChanged;
  final ValueChanged<int> onChapterSelected;
  final TextReadingPreferences preferences;
  final ValueChanged<FlowPagination> onPaginationChanged;

  @override
  State<_DeferredFlowChapterView> createState() =>
      _DeferredFlowChapterViewState();
}

class _DeferredFlowChapterViewState extends State<_DeferredFlowChapterView> {
  late Future<FlowChapter> _chapter;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _chapter = widget.loadChapter();
    widget.snapshotController?.prepare = _prepare;
  }

  Future<void> _prepare() async {
    if (_failed) {
      _failed = false;
      final chapter = widget.loadChapter();
      setState(() {
        _chapter = chapter;
      });
    }
    await _chapter;
  }

  @override
  void dispose() {
    widget.snapshotController?.prepare = null;
    widget.snapshotController?.cancelPending();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<FlowChapter>(
    future: _chapter,
    initialData: widget.initialChapter,
    builder: (context, snapshot) {
      _failed = snapshot.hasError;
      return switch (snapshot) {
        AsyncSnapshot(:final data?) => FlowChapterRenderer(
          chapter: data,
          previewOnly: widget.previewOnly,
          snapshotController: widget.snapshotController,
          captureChapterPage: widget.captureChapterPage,
          loadAdjacentChapter: widget.loadAdjacentChapter,
          initialPosition: widget.initialPosition,
          onPreviousChapter: widget.onPreviousChapter,
          onNextChapter: widget.onNextChapter,
          onPositionChanged: widget.onPositionChanged,
          onChapterSelected: widget.onChapterSelected,
          preferences: widget.preferences,
          onPaginationChanged: widget.onPaginationChanged,
        ),
        AsyncSnapshot(:final error?) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              AppLocalizations.of(context)
                  .unableToLoadChapter(error.toString()),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      };
    },
  );
}

class FlowChapterRenderer extends StatefulWidget {
  const FlowChapterRenderer({
    super.key,
    required this.chapter,
    required this.initialPosition,
    this.loadAdjacentChapter,
    this.onPreviousChapter,
    this.onNextChapter,
    required this.onPositionChanged,
    required this.onChapterSelected,
    required this.preferences,
    this.onPaginationChanged,
    this.previewOnly = false,
    this.snapshotController,
    this.captureChapterPage,
  });

  final FlowChapter chapter;
  final bool previewOnly;
  final FlowPageSnapshotController? snapshotController;
  final Future<ui.Image?> Function(int direction)? captureChapterPage;
  final TextOffsetLocator initialPosition;
  final Future<FlowChapter> Function(int direction)? loadAdjacentChapter;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;
  final ValueChanged<TextOffsetLocator> onPositionChanged;
  final ValueChanged<int> onChapterSelected;
  final TextReadingPreferences preferences;
  final ValueChanged<FlowPagination>? onPaginationChanged;

  @override
  State<FlowChapterRenderer> createState() => _FlowChapterRendererState();
}

class _FlowChapterRendererState extends State<FlowChapterRenderer> {
  final _linkRecognizers = <int, TapGestureRecognizer>{};
  Object? _bodyRevision;
  Widget? _body;

  @override
  void dispose() {
    for (final recognizer in _linkRecognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = widget.preferences.horizontalPadding.clamp(
          0.0,
          constraints.maxWidth / 4,
        );
        return FlowContentViewport(
          pagePadding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            8,
          ),
          paperColor: _backgroundColor(widget.preferences.appearance),
          contentRevision: (
            widget.chapter,
            widget.preferences.fontSize,
            widget.preferences.lineHeight,
            widget.preferences.horizontalPadding,
            widget.preferences.appearance,
            MediaQuery.textScalerOf(context),
            MediaQuery.devicePixelRatioOf(context),
          ),
          previewOnly: widget.previewOnly,
          snapshotController: widget.snapshotController,
          captureChapterPage: widget.captureChapterPage,
          prepareChapter: widget.loadAdjacentChapter == null
              ? null
              : (direction) async {
                  final chapter = await widget.loadAdjacentChapter!(direction);
                  if (!mounted) return null;
                  return (onReady) => FlowChapterRenderer(
                    chapter: chapter,
                    initialPosition: TextOffsetLocator(
                      chapterIndex: chapter.index,
                      offset: direction > 0 ? 0 : 1 << 31,
                    ),
                    preferences: widget.preferences,
                    previewOnly: true,
                    onPositionChanged: (_) {},
                    onChapterSelected: (_) {},
                    onPaginationChanged: (_) => onReady(),
                  );
                },
          position: widget.initialPosition,
          mode: widget.preferences.mode,
          onPositionChanged: widget.onPositionChanged,
          onPreviousChapter: widget.onPreviousChapter,
          onNextChapter: widget.onNextChapter,
          onPaginationChanged: widget.onPaginationChanged,
          controlsBuilder: widget.onPaginationChanged == null
              ? null
              : (context, pagination) => const SizedBox.shrink(),
          child: _chapterBody(context, constraints, horizontalPadding),
        );
      },
    );
  }

  Widget _chapterBody(
    BuildContext context,
    BoxConstraints constraints,
    double horizontalPadding,
  ) {
    final revision = (
      widget.chapter,
      constraints,
      horizontalPadding,
      widget.preferences.fontSize,
      widget.preferences.lineHeight,
      widget.preferences.appearance,
      Theme.of(context).textTheme,
      MediaQuery.textScalerOf(context),
    );
    if (_bodyRevision != revision) {
      _bodyRevision = revision;
      _body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.chapter.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: _foregroundColor(widget.preferences.appearance),
            ),
          ),
          const SizedBox(height: 28),
          // EPUB currently supplies this transitional adapter. The
          // semantic FlowBlock renderer will replace it in a follow-up.
          if (widget.chapter.hasTransitionalHtml)
            Html(
              data: widget.chapter.transitionalHtml!,
              extensions: [
                TagWrapExtension(
                  tagsToWrap: const {'img'},
                  builder: (child) => ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth - horizontalPadding * 2,
                      maxHeight: (constraints.maxHeight - 96).clamp(
                        48,
                        double.infinity,
                      ),
                    ),
                    child: child,
                  ),
                ),
                TagWrapExtension(
                  tagsToWrap: const {'table'},
                  builder: (child) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: child,
                  ),
                ),
                const TableHtmlExtension(),
              ],
              onLinkTap: (url, attributes, element) {
                final uri = url == null ? null : Uri.tryParse(url);
                final chapterIndex = int.tryParse(
                  uri?.pathSegments.singleOrNull ?? '',
                );
                if (uri?.scheme == 'fbooks' &&
                    uri?.host == 'chapter' &&
                    chapterIndex != null) {
                  widget.onChapterSelected(chapterIndex);
                }
              },
              style: {
                // 出版物对子节点的 CSS 会覆盖 body 的继承值，阅读偏好
                // 必须直接应用到每个元素，才能按当前字号和行高重新分页。
                '*': Style(
                  color: _foregroundColor(widget.preferences.appearance),
                  fontSize: FontSize(widget.preferences.fontSize),
                  lineHeight: LineHeight(widget.preferences.lineHeight),
                ),
                'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
                for (final (tag, scale) in [
                  ('h1', 2.0),
                  ('h2', 1.5),
                  ('h3', 1.17),
                  ('h4', 1.0),
                  ('h5', 0.83),
                  ('h6', 0.67),
                ])
                  tag: Style(
                    fontSize: FontSize(widget.preferences.fontSize * scale),
                  ),
              },
            )
          else
            Text.rich(
              TextSpan(
                children: _chapterTextSpans(
                  context,
                  widget.chapter,
                  widget.preferences,
                  _linkRecognizerFor,
                ),
              ),
            ),
        ],
      );
    }
    return _body!;
  }

  TapGestureRecognizer _linkRecognizerFor(int chapterIndex) {
    final recognizer = _linkRecognizers.putIfAbsent(
      chapterIndex,
      TapGestureRecognizer.new,
    );
    recognizer.onTap = () => widget.onChapterSelected(chapterIndex);
    return recognizer;
  }
}

List<InlineSpan> _chapterTextSpans(
  BuildContext context,
  FlowChapter chapter,
  TextReadingPreferences preferences,
  TapGestureRecognizer Function(int chapterIndex) linkRecognizerFor,
) {
  final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
    color: _foregroundColor(preferences.appearance),
    fontSize: preferences.fontSize,
    height: preferences.lineHeight,
  );
  final segments = chapter.inlines.isEmpty
      ? [FlowInline(text: chapter.text)]
      : chapter.inlines;
  return [
    for (final segment in segments)
      if (segment.isImage)
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _InlineEpubImage(bytes: segment.imageBytes!),
        )
      else if (segment.isTable)
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _InlineEpubTable(table: segment.table!),
        )
      else
        TextSpan(
          text: segment.text,
          style: _segmentTextStyle(baseStyle, segment),
          recognizer: switch (segment.linkTargetChapterIndex) {
            final chapterIndex? => linkRecognizerFor(chapterIndex),
            null => null,
          },
        ),
  ];
}

class _InlineEpubImage extends StatelessWidget {
  const _InlineEpubImage({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300, maxHeight: 320),
      child: Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image_outlined),
      ),
    ),
  );
}

class _InlineEpubTable extends StatelessWidget {
  const _InlineEpubTable({required this.table});

  final FlowTable table;

  @override
  Widget build(BuildContext context) {
    final foreground = DefaultTextStyle.of(context).style.color;
    final columnCount = table.rows.fold<int>(
      0,
      (count, row) => count > row.length ? count : row.length,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          border: TableBorder.all(
            color: foreground?.withValues(alpha: 0.3) ?? Colors.black26,
          ),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            for (final row in table.rows)
              TableRow(
                children: [
                  for (var index = 0; index < columnCount; index++)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(index < row.length ? row[index] : ''),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

TextStyle? _segmentTextStyle(TextStyle? baseStyle, FlowInline segment) {
  final emphasizedStyle = segment.emphasized
      ? baseStyle?.copyWith(fontStyle: FontStyle.italic)
      : baseStyle;
  return segment.linkTargetChapterIndex == null
      ? emphasizedStyle
      : emphasizedStyle?.copyWith(
          color: emphasizedStyle.color?.withValues(alpha: 0.8),
          decoration: TextDecoration.underline,
        );
}

Future<void> _showTextReadingSettings(
  BuildContext context,
  WidgetRef ref, {
  required bool desktop,
}) {
  return showReaderSettingsSurface(
    context,
    desktop: desktop,
    desktopKey: const Key('text-reader-desktop-settings'),
    child: _TextReadingSettingsPanel(ref: ref, desktop: desktop),
  );
}

class _TextReadingSettingsPanel extends StatefulWidget {
  const _TextReadingSettingsPanel({required this.ref, required this.desktop});

  final WidgetRef ref;
  final bool desktop;

  @override
  State<_TextReadingSettingsPanel> createState() =>
      _TextReadingSettingsPanelState();
}

class _TextReadingSettingsPanelState extends State<_TextReadingSettingsPanel> {
  late TextReadingPreferences preferences;

  @override
  void initState() {
    super.initState();
    preferences =
        widget.ref.read(textReadingPreferencesProvider).asData?.value ??
        TextReadingPreferences.defaults;
  }

  Future<void> _update(TextReadingPreferences next) async {
    setState(() => preferences = next);
    await widget.ref.read(textReadingPreferencesRepositoryProvider).save(next);
    widget.ref.invalidate(textReadingPreferencesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final appearance = preferences.appearance;
    final theme = _textReaderTheme(appearance);
    return Theme(
      data: theme,
      child: Material(
        key: const Key('text-reading-settings-surface'),
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).readingSettings,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context).closeSettings,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<TextReadingMode>(
                  isExpanded: true,
                  initialValue: preferences.mode,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).readingMode,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: TextReadingMode.paged,
                      child: Text(AppLocalizations.of(context).textPagedMode),
                    ),
                    DropdownMenuItem(
                      value: TextReadingMode.scroll,
                      child: Text(AppLocalizations.of(context).textScrollMode),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) _update(preferences.copyWith(mode: mode));
                  },
                ),
                const SizedBox(height: 20),
                _TextPreferenceSlider(
                  label: AppLocalizations.of(context).textSize,
                  valueLabel: '${preferences.fontSize.round()} pt',
                  value: preferences.fontSize,
                  min: 14,
                  max: 28,
                  divisions: 14,
                  onChanged: (value) =>
                      _update(preferences.copyWith(fontSize: value)),
                ),
                const SizedBox(height: 12),
                _TextPreferenceSlider(
                  label: AppLocalizations.of(context).lineHeight,
                  valueLabel: preferences.lineHeight.toStringAsFixed(1),
                  value: preferences.lineHeight,
                  min: 1.3,
                  max: 2.1,
                  divisions: 8,
                  onChanged: (value) =>
                      _update(preferences.copyWith(lineHeight: value)),
                ),
                const SizedBox(height: 12),
                _TextPreferenceSlider(
                  label: AppLocalizations.of(context).pageMargins,
                  valueLabel: '${preferences.horizontalPadding.round()} px',
                  value: preferences.horizontalPadding,
                  min: 16,
                  max: 64,
                  divisions: 6,
                  onChanged: (value) =>
                      _update(preferences.copyWith(horizontalPadding: value)),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).readerAppearance,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (appearance, label) in [
                        (
                          TextReadingAppearance.light,
                          AppLocalizations.of(context).light,
                        ),
                        (
                          TextReadingAppearance.sepia,
                          AppLocalizations.of(context).sepia,
                        ),
                        (
                          TextReadingAppearance.dark,
                          AppLocalizations.of(context).dark,
                        ),
                      ])
                        SizedBox(
                          width: (constraints.maxWidth - 8) / 2,
                          child: OutlinedButton(
                            key: Key('text-appearance-${appearance.name}'),
                            onPressed: () => _update(
                              preferences.copyWith(appearance: appearance),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _backgroundColor(appearance),
                              foregroundColor: _foregroundColor(appearance),
                              side: BorderSide(
                                color: preferences.appearance == appearance
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                                width: preferences.appearance == appearance
                                    ? 2
                                    : 1,
                              ),
                            ),
                            child: Text(label),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
      Text('$label: $valueLabel', style: Theme.of(context).textTheme.bodySmall),
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
      TextReadingAppearance.light => Colors.white,
      TextReadingAppearance.dark => const Color(0xFF1A1A1A),
      TextReadingAppearance.sepia => const Color(0xFFF5F1E8),
    };

ThemeData _textReaderTheme(TextReadingAppearance appearance) {
  final dark = appearance == TextReadingAppearance.dark;
  final colors =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: dark ? const Color(0xFFD0BCFF) : const Color(0xFF6750A4),
        surface: dark ? const Color(0xFF1C1B1F) : const Color(0xFFFFFBFE),
        onSurface: dark ? const Color(0xFFE6E1E5) : const Color(0xFF1C1B1F),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

Color _foregroundColor(TextReadingAppearance appearance) =>
    switch (appearance) {
      TextReadingAppearance.light => Colors.black,
      TextReadingAppearance.sepia => const Color(0xFF333333),
      TextReadingAppearance.dark => const Color(0xFFE0E0E0),
    };
