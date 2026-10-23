import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fbooks/app/providers.dart';
import 'package:fbooks/domain/collection/book_collection.dart';
import 'package:fbooks/features/reader/presentation/reader_chrome.dart';
import 'package:fbooks/application/reader/comic_reader_session.dart';
import 'package:fbooks/application/reader/comic_spread_index.dart';
import 'package:fbooks/application/reader/vertical_comic_page_position.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/comic_reading_preferences.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding.dart';
import 'package:fbooks/features/reader/presentation/reader_settings_surface.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ComicReaderPage extends ConsumerStatefulWidget {
  const ComicReaderPage({
    super.key,
    required this.publicationId,
    required this.title,
  });

  final PublicationId publicationId;
  final String title;

  @override
  ConsumerState<ComicReaderPage> createState() => _ComicReaderPageState();
}

class _ComicReaderPageState extends ConsumerState<ComicReaderPage> {
  var _controlsVisible = true;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final session = ref.watch(comicReaderSessionProvider(widget.publicationId));
    final preferences =
        ref.watch(comicReadingPreferencesProvider).value ??
        ComicReadingPreferences.defaults;
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Stack(
        children: [
          Positioned.fill(
            child: session.when(
              data: (value) => _ComicPageView(
                publicationId: widget.publicationId,
                session: value,
                preferences: preferences,
                desktop: desktop,
                controlsVisible: _controlsVisible,
                onToggleControls: () =>
                    setState(() => _controlsVisible = !_controlsVisible),
              ),
              error: (error, stackTrace) => _ReaderErrorView(error: error),
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: AnimatedOpacity(
                key: const Key('comic-reader-toolbar-visibility'),
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: ReaderToolbar(
                  key: const Key('comic-reader-toolbar'),
                  title: widget.title,
                  overlay: true,
                  height: MediaQuery.sizeOf(context).width < 600 ? 56 : 64,
                  actions: [
                    const ReaderFullscreenButton(color: Colors.white),
                    IconButton(
                      tooltip: AppLocalizations.of(context).readingSettings,
                      color: Colors.white,
                      onPressed: () => _showComicReadingSettings(
                        context,
                        ref,
                        publicationId: widget.publicationId,
                      ),
                      icon: const Icon(Icons.settings),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComicPageView extends ConsumerStatefulWidget {
  const _ComicPageView({
    required this.publicationId,
    required this.session,
    required this.preferences,
    required this.desktop,
    required this.controlsVisible,
    required this.onToggleControls,
  });

  final PublicationId publicationId;
  final ComicReaderSession session;
  final ComicReadingPreferences preferences;
  final bool desktop;
  final bool controlsVisible;
  final VoidCallback onToggleControls;

  @override
  ConsumerState<_ComicPageView> createState() => _ComicPageViewState();
}

class _ComicPageViewState extends ConsumerState<_ComicPageView> {
  late final PageController _pageController;
  late final ScrollController _verticalScrollController;
  final _verticalPageKeys = <int, GlobalKey>{};
  bool _hasRestoredPosition = false;
  var _currentPage = 0;
  Timer? _pendingVerticalPageSync;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _verticalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _pendingVerticalPageSync?.cancel();
    _pageController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ComicPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences.mode == widget.preferences.mode &&
        oldWidget.preferences.usesDoublePage ==
            widget.preferences.usesDoublePage) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.preferences.mode == ComicReadingMode.vertical) {
        unawaited(_goToVerticalPage(_currentPage, animate: false));
      } else if (_pageController.hasClients) {
        _pageController.jumpToPage(_viewerIndexForPage(_currentPage));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(readingProgressProvider(widget.publicationId));
    final pageCount = widget.session.document.pages.length;
    if (pageCount == 0) {
      return const _ReaderEmptyContentView(
        message: 'This comic does not contain any readable image pages.',
      );
    }
    progress.whenData(_restorePosition);
    final reader = widget.preferences.mode == ComicReadingMode.vertical
        ? _buildVerticalReader(pageCount)
        : PageView.builder(
            controller: _pageController,
            itemCount: _viewerCount,
            reverse: widget.preferences.mode == ComicReadingMode.rightToLeft,
            onPageChanged: (index) => _savePosition(_firstPageForViewer(index)),
            itemBuilder: (context, index) {
              return _ComicPageSpread(
                session: widget.session,
                firstPage: _firstPageForViewer(index),
                doublePage: widget.preferences.usesDoublePage,
                rightToLeft:
                    widget.preferences.mode == ComicReadingMode.rightToLeft,
              );
            },
          );
    final vertical = widget.preferences.mode == ComicReadingMode.vertical;
    final rightToLeft = widget.preferences.mode == ComicReadingMode.rightToLeft;
    final lastVisiblePage =
        widget.preferences.usesDoublePage && _currentPage > 0
        ? (_currentPage + 1).clamp(0, pageCount - 1)
        : _currentPage;
    final canGoBack = _currentPage > 0;
    final canGoForward = lastVisiblePage < pageCount - 1;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('comic-reader-stage-gesture'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggleControls,
            child: _ComicReaderStage(
              desktop: widget.desktop,
              vertical: vertical,
              child: reader,
            ),
          ),
        ),
        if (vertical)
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: widget.controlsVisible ? 1 : .3,
                duration: const Duration(milliseconds: 250),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ComicTurnButton(
                      icon: Icons.keyboard_arrow_up,
                      tooltip: AppLocalizations.of(context).previousPage,
                      onPressed: canGoBack ? _goToPrevious : null,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    _ComicTurnButton(
                      icon: Icons.keyboard_arrow_down,
                      tooltip: AppLocalizations.of(context).nextPage,
                      onPressed: canGoForward ? _goToNext : null,
                      size: 40,
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          Positioned(
            left: 10,
            top: 0,
            bottom: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: widget.controlsVisible ? 1 : .4,
                duration: const Duration(milliseconds: 250),
                child: _ComicTurnButton(
                  key: const Key('comic-turn-left'),
                  icon: rightToLeft ? Icons.chevron_right : Icons.chevron_left,
                  tooltip: rightToLeft
                      ? AppLocalizations.of(context).nextPage
                      : AppLocalizations.of(context).previousPage,
                  onPressed: rightToLeft
                      ? (canGoForward ? _goToNext : null)
                      : (canGoBack ? _goToPrevious : null),
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 0,
            bottom: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: widget.controlsVisible ? 1 : .4,
                duration: const Duration(milliseconds: 250),
                child: _ComicTurnButton(
                  key: const Key('comic-turn-right'),
                  icon: rightToLeft ? Icons.chevron_left : Icons.chevron_right,
                  tooltip: rightToLeft
                      ? AppLocalizations.of(context).previousPage
                      : AppLocalizations.of(context).nextPage,
                  onPressed: rightToLeft
                      ? (canGoBack ? _goToPrevious : null)
                      : (canGoForward ? _goToNext : null),
                ),
              ),
            ),
          ),
        ],
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !widget.controlsVisible,
            child: AnimatedOpacity(
              key: const Key('comic-reader-progress-visibility'),
              opacity: widget.controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: _ComicPageControls(
                currentPage: _currentPage,
                pageCount: pageCount,
                onPageSelected: _goToPage,
                doublePage: widget.preferences.usesDoublePage,
                rightToLeft: rightToLeft,
              ),
            ),
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
    if (locator is! ComicPageLocator) {
      return;
    }

    final lastPage = widget.session.document.pages.length - 1;
    final pageIndex = locator.pageIndex.clamp(0, lastPage).toInt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() => _currentPage = pageIndex);
      if (widget.preferences.mode == ComicReadingMode.vertical) {
        unawaited(_goToVerticalPage(pageIndex, animate: false));
      } else if (_pageController.hasClients) {
        _pageController.jumpToPage(_viewerIndexForPage(pageIndex));
      }
    });
  }

  void _savePosition(int pageIndex) {
    setState(() => _currentPage = pageIndex);
    unawaited(_persistPosition(pageIndex));
  }

  Future<void> _goToPage(int pageIndex) async {
    if (widget.preferences.mode == ComicReadingMode.vertical) {
      await _goToVerticalPage(pageIndex);
      return;
    }
    await _goToViewer(_viewerIndexForPage(pageIndex));
  }

  Future<void> _goToPrevious() {
    if (widget.preferences.mode == ComicReadingMode.vertical) {
      return _goToVerticalPage(_currentPage - 1);
    }
    return _goToViewer(
      (_viewerIndexForPage(_currentPage) - 1).clamp(0, _viewerCount - 1),
    );
  }

  Future<void> _goToNext() {
    if (widget.preferences.mode == ComicReadingMode.vertical) {
      return _goToVerticalPage(_currentPage + 1);
    }
    return _goToViewer(
      (_viewerIndexForPage(_currentPage) + 1).clamp(0, _viewerCount - 1),
    );
  }

  Future<void> _goToViewer(int viewerIndex) async {
    if (!_pageController.hasClients ||
        viewerIndex == _viewerIndexForPage(_currentPage)) {
      return;
    }
    await _pageController.animateToPage(
      viewerIndex,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  Widget _buildVerticalReader(int pageCount) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleVerticalScroll,
      child: ListView.builder(
        controller: _verticalScrollController,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: pageCount,
        itemBuilder: (context, index) => _VerticalComicPage(
          key: _verticalPageKeys.putIfAbsent(index, GlobalKey.new),
          session: widget.session,
          pageIndex: index,
        ),
      ),
    );
  }

  bool _handleVerticalScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    _pendingVerticalPageSync?.cancel();
    _pendingVerticalPageSync = Timer(
      const Duration(milliseconds: 120),
      _syncCurrentVerticalPage,
    );
    return false;
  }

  void _syncCurrentVerticalPage() {
    if (!mounted || widget.preferences.mode != ComicReadingMode.vertical) {
      return;
    }
    final targetY = MediaQuery.sizeOf(context).height / 2;
    var nearestPage = _currentPage;
    var nearestDistance = double.infinity;
    for (final entry in _verticalPageKeys.entries) {
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) {
        continue;
      }
      final pageTop = renderObject.localToGlobal(Offset.zero).dy;
      final distance = (pageTop - targetY).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestPage = entry.key;
      }
    }
    if (nearestPage != _currentPage) {
      _savePosition(nearestPage);
    }
  }

  Future<void> _goToVerticalPage(int pageIndex, {bool animate = true}) async {
    if (!_verticalScrollController.hasClients) {
      return;
    }
    final targetPage = pageIndex
        .clamp(0, widget.session.document.pages.length - 1)
        .toInt();
    _savePosition(targetPage);
    final targetContext = _verticalPageKeys[targetPage]?.currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: .05,
        duration: animate ? const Duration(milliseconds: 220) : Duration.zero,
        curve: Curves.easeOut,
      );
      return;
    }

    final targetOffset = VerticalComicPagePosition.estimateOffset(
      pageIndex: targetPage,
      pageCount: widget.session.document.pages.length,
      maxScrollExtent: _verticalScrollController.position.maxScrollExtent,
    );
    if (animate) {
      await _verticalScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _verticalScrollController.jumpTo(targetOffset);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.preferences.mode != ComicReadingMode.vertical) {
        return;
      }
      final context = _verticalPageKeys[targetPage]?.currentContext;
      if (context != null) {
        unawaited(
          Scrollable.ensureVisible(
            context,
            alignment: .05,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  int get _viewerCount {
    return ComicSpreadIndex.viewerCount(
      pageCount: widget.session.document.pages.length,
      doublePage: widget.preferences.usesDoublePage,
    );
  }

  int _viewerIndexForPage(int pageIndex) {
    return ComicSpreadIndex.viewerIndexForPage(
      pageIndex: pageIndex,
      doublePage: widget.preferences.usesDoublePage,
    );
  }

  int _firstPageForViewer(int viewerIndex) {
    return ComicSpreadIndex.firstPageForViewer(
      viewerIndex: viewerIndex,
      doublePage: widget.preferences.usesDoublePage,
    );
  }

  Future<void> _persistPosition(int pageIndex) async {
    try {
      await ref
          .read(readingProgressRepositoryProvider)
          .save(
            ReadingProgress(
              publicationId: widget.publicationId,
              locator: ComicPageLocator(pageIndex),
              updatedAt: DateTime.now(),
            ),
          );
      if (pageIndex == widget.session.document.pages.length - 1) {
        await ref
            .read(bookCollectionRepositoryProvider)
            .addPublication(
              SystemBookCollections.finished,
              widget.publicationId,
            );
      }
    } catch (_) {
      // A failed progress write must not interrupt reading.
    }
  }
}

class _ComicTurnButton extends StatelessWidget {
  const _ComicTurnButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 48,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => ClipOval(
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: Size.square(size),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white.withValues(alpha: .13),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: .04),
          disabledForegroundColor: Colors.white.withValues(alpha: .18),
          shape: const CircleBorder(),
        ),
        icon: Icon(icon),
      ),
    ),
  );
}

class _ComicPageControls extends StatelessWidget {
  const _ComicPageControls({
    required this.currentPage,
    required this.pageCount,
    required this.onPageSelected,
    required this.doublePage,
    required this.rightToLeft,
  });

  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageSelected;
  final bool doublePage;
  final bool rightToLeft;

  @override
  Widget build(BuildContext context) {
    final lastVisiblePage = doublePage && currentPage > 0
        ? (currentPage + 1).clamp(0, pageCount - 1)
        : currentPage;
    final pageLabel = lastVisiblePage == currentPage
        ? '${currentPage + 1} / $pageCount'
        : '${currentPage + 1}–${lastVisiblePage + 1} / $pageCount';
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: .8), Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        pageLabel,
                        key: const Key('comic-page-label'),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: .65),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Directionality(
                        textDirection: rightToLeft
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            key: const Key('comic-page-slider'),
                            value: currentPage.toDouble(),
                            min: 0,
                            max: (pageCount - 1).toDouble(),
                            divisions: pageCount > 1 ? pageCount - 1 : null,
                            label: pageLabel,
                            onChanged: pageCount > 1
                                ? (value) => onPageSelected(value.round())
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComicReaderStage extends StatelessWidget {
  const _ComicReaderStage({
    required this.desktop,
    required this.vertical,
    required this.child,
  });
  final bool desktop;
  final bool vertical;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    key: desktop
        ? const Key('comic-reader-desktop-stage')
        : const Key('comic-reader-compact-stage'),
    child: Padding(
      padding: vertical
          ? const EdgeInsets.only(top: 64)
          : const EdgeInsets.symmetric(horizontal: 56, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: vertical ? 800 : double.infinity,
          ),
          child: child,
        ),
      ),
    ),
  );
}

class _ComicPageSpread extends StatelessWidget {
  const _ComicPageSpread({
    required this.session,
    required this.firstPage,
    required this.doublePage,
    required this.rightToLeft,
  });

  final ComicReaderSession session;
  final int firstPage;
  final bool doublePage;
  final bool rightToLeft;

  @override
  Widget build(BuildContext context) {
    final pageCount = session.document.pages.length;
    if (!doublePage || firstPage == 0 || firstPage + 1 >= pageCount) {
      return _ComicImage(session: session, pageIndex: firstPage);
    }
    final pageIndexes = rightToLeft
        ? [firstPage + 1, firstPage]
        : [firstPage, firstPage + 1];
    return Row(
      children: [
        for (final pageIndex in pageIndexes) ...[
          if (pageIndex != pageIndexes.first) const SizedBox(width: 4),
          Expanded(
            child: _ComicImage(session: session, pageIndex: pageIndex),
          ),
        ],
      ],
    );
  }
}

class _VerticalComicPage extends StatelessWidget {
  const _VerticalComicPage({
    super.key,
    required this.session,
    required this.pageIndex,
  });

  final ComicReaderSession session;
  final int pageIndex;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: _ComicImage(session: session, pageIndex: pageIndex, fitWidth: true),
  );
}

class _ComicImage extends StatefulWidget {
  const _ComicImage({
    required this.session,
    required this.pageIndex,
    this.fitWidth = false,
  });

  final ComicReaderSession session;
  final int pageIndex;
  final bool fitWidth;

  @override
  State<_ComicImage> createState() => _ComicImageState();
}

class _ComicImageState extends State<_ComicImage> {
  // 工具栏显隐只重建界面，沿用同一图片请求以避免重新读取和闪烁。
  late Future<Uint8List> _pageBytes;

  @override
  void initState() {
    super.initState();
    _pageBytes = widget.session.readPage(widget.pageIndex);
  }

  @override
  void didUpdateWidget(covariant _ComicImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        oldWidget.pageIndex != widget.pageIndex) {
      _pageBytes = widget.session.readPage(widget.pageIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _pageBytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ReaderErrorView(error: snapshot.error!);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return LayoutBuilder(
          builder: (context, constraints) => InteractiveViewer(
            maxScale: 4,
            child: widget.fitWidth
                ? Image.memory(
                    snapshot.data!,
                    width: constraints.maxWidth,
                    fit: BoxFit.fitWidth,
                  )
                : SizedBox.expand(
                    child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                  ),
          ),
        );
      },
    );
  }
}

Future<void> _showComicReadingSettings(
  BuildContext context,
  WidgetRef ref, {
  required PublicationId publicationId,
}) {
  return showReaderSettingsSurface(
    context,
    desktop: false,
    desktopKey: const Key('comic-reader-desktop-settings'),
    child: _ComicReadingSettingsPanel(ref: ref, publicationId: publicationId),
  );
}

class _ComicReadingSettingsPanel extends StatefulWidget {
  const _ComicReadingSettingsPanel({
    required this.ref,
    required this.publicationId,
  });

  final WidgetRef ref;
  final PublicationId publicationId;

  @override
  State<_ComicReadingSettingsPanel> createState() =>
      _ComicReadingSettingsPanelState();
}

class _ComicReadingSettingsPanelState
    extends State<_ComicReadingSettingsPanel> {
  late ComicReadingPreferences preferences;
  var fileNameEncoding = ComicArchiveFileNameEncoding.auto;

  @override
  void initState() {
    super.initState();
    preferences =
        widget.ref.read(comicReadingPreferencesProvider).asData?.value ??
        ComicReadingPreferences.defaults;
    _loadFileNameEncoding();
  }

  Future<void> _loadFileNameEncoding() async {
    final value = await widget.ref
        .read(comicArchiveFileNameEncodingRepositoryProvider)
        .load(widget.publicationId);
    if (!mounted) {
      return;
    }
    setState(() {
      fileNameEncoding = ComicArchiveFileNameEncodingX.fromStorageName(value);
    });
  }

  Future<void> _update(ComicReadingPreferences next) async {
    setState(() => preferences = next);
    await widget.ref.read(comicReadingPreferencesRepositoryProvider).save(next);
    widget.ref.invalidate(comicReadingPreferencesProvider);
  }

  Future<void> _updateFileNameEncoding(
    ComicArchiveFileNameEncoding next,
  ) async {
    setState(() => fileNameEncoding = next);
    await widget.ref
        .read(comicArchiveFileNameEncodingRepositoryProvider)
        .save(widget.publicationId, next.storageName);
    widget.ref.invalidate(comicReaderSessionProvider(widget.publicationId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vertical = preferences.mode == ComicReadingMode.vertical;
    return Material(
      key: const Key('comic-reading-settings-surface'),
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).readingSettings,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
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
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).readingMode,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ComicReadingMode>(
                key: const Key('comic-reading-direction'),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  ),
                ),
                segments: [
                  for (final mode in ComicReadingMode.values)
                    ButtonSegment(
                      value: mode,
                      tooltip: _modeLabel(context, mode),
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(switch (mode) {
                            ComicReadingMode.leftToRight => Icons.chevron_right,
                            ComicReadingMode.rightToLeft => Icons.chevron_left,
                            ComicReadingMode.vertical =>
                              Icons.keyboard_arrow_down,
                          }, size: 18),
                          const SizedBox(height: 2),
                          Text(
                            _modeLabel(context, mode),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
                selected: {preferences.mode},
                onSelectionChanged: (selection) =>
                    _update(preferences.copyWith(mode: selection.single)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(),
              ),
              Text(
                AppLocalizations.of(context).doublePageSpread,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                key: const Key('comic-reading-page-layout'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Single page'),
                    icon: Icon(Icons.view_carousel_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Double page'),
                    icon: Icon(Icons.view_column_outlined),
                  ),
                ],
                selected: {preferences.doublePage},
                onSelectionChanged: vertical
                    ? null
                    : (selection) => _update(
                        preferences.copyWith(doublePage: selection.single),
                      ),
              ),
              if (vertical) ...[
                const SizedBox(height: 8),
                Text(
                  'Available in horizontal reading modes.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(),
              ),
              DropdownButtonFormField<ComicArchiveFileNameEncoding>(
                key: ValueKey(fileNameEncoding),
                initialValue: fileNameEncoding,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Archive file name encoding',
                ),
                items: [
                  for (final encoding in ComicArchiveFileNameEncoding.values)
                    DropdownMenuItem(
                      value: encoding,
                      child: Text(encoding.displayName),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) _updateFileNameEncoding(value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _modeLabel(BuildContext context, ComicReadingMode mode) {
  return switch (mode) {
    ComicReadingMode.leftToRight => 'Left to right',
    ComicReadingMode.rightToLeft => 'Right to left',
    ComicReadingMode.vertical => 'Vertical scroll',
  };
}

class _ReaderErrorView extends StatelessWidget {
  const _ReaderErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (error) {
      FileSystemException() => (
        'File unavailable',
        'The original comic file can no longer be found. Re-import it to continue reading.',
      ),
      FormatException() => (
        'Comic cannot be read',
        'This file is incomplete or uses an unsupported comic format.',
      ),
      _ => ('Unable to open this comic', error.toString()),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderEmptyContentView extends StatelessWidget {
  const _ReaderEmptyContentView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hide_image_outlined,
            size: 52,
            color: Colors.white70,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).readerEmptyTitle,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}
