import 'dart:async';
import 'dart:typed_data';

import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/reader/comic_reader_session.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/comic_reading_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ComicReaderPage extends ConsumerWidget {
  const ComicReaderPage({
    super.key,
    required this.publicationId,
    required this.title,
  });

  final PublicationId publicationId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(comicReaderSessionProvider(publicationId));
    final preferences =
        ref.watch(comicReadingPreferencesProvider).value ??
        ComicReadingPreferences.defaults;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.black,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Reading settings',
            onPressed: () => _showComicReadingSettings(context, ref),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: session.when(
        data: (value) => _ComicPageView(
          publicationId: publicationId,
          session: value,
          preferences: preferences,
        ),
        error: (error, stackTrace) => _ReaderErrorView(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ComicPageView extends ConsumerStatefulWidget {
  const _ComicPageView({
    required this.publicationId,
    required this.session,
    required this.preferences,
  });

  final PublicationId publicationId;
  final ComicReaderSession session;
  final ComicReadingPreferences preferences;

  @override
  ConsumerState<_ComicPageView> createState() => _ComicPageViewState();
}

class _ComicPageViewState extends ConsumerState<_ComicPageView> {
  late final PageController _pageController;
  bool _hasRestoredPosition = false;
  var _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
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
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(_viewerIndexForPage(_currentPage));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(readingProgressProvider(widget.publicationId));
    progress.whenData(_restorePosition);
    final pageCount = widget.session.document.pages.length;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _viewerCount,
            scrollDirection:
                widget.preferences.mode == ComicReadingMode.vertical
                ? Axis.vertical
                : Axis.horizontal,
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
          ),
        ),
        _ComicPageControls(
          currentPage: _currentPage,
          pageCount: pageCount,
          onPageSelected: _goToPage,
          onPrevious: _goToPrevious,
          onNext: _goToNext,
          doublePage: widget.preferences.usesDoublePage,
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
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(_viewerIndexForPage(pageIndex));
        setState(() => _currentPage = pageIndex);
      }
    });
  }

  void _savePosition(int pageIndex) {
    setState(() => _currentPage = pageIndex);
    unawaited(_persistPosition(pageIndex));
  }

  Future<void> _goToPage(int pageIndex) async {
    await _goToViewer(_viewerIndexForPage(pageIndex));
  }

  Future<void> _goToPrevious() => _goToViewer(
    (_viewerIndexForPage(_currentPage) - 1).clamp(0, _viewerCount - 1),
  );

  Future<void> _goToNext() => _goToViewer(
    (_viewerIndexForPage(_currentPage) + 1).clamp(0, _viewerCount - 1),
  );

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

  int get _viewerCount {
    final pages = widget.session.document.pages.length;
    if (!widget.preferences.usesDoublePage || pages <= 1) {
      return pages;
    }
    return 1 + (pages - 1 + 1) ~/ 2;
  }

  int _viewerIndexForPage(int pageIndex) {
    if (!widget.preferences.usesDoublePage || pageIndex == 0) {
      return pageIndex;
    }
    return 1 + (pageIndex - 1) ~/ 2;
  }

  int _firstPageForViewer(int viewerIndex) {
    if (!widget.preferences.usesDoublePage || viewerIndex == 0) {
      return viewerIndex;
    }
    return 1 + (viewerIndex - 1) * 2;
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
    } catch (_) {
      // A failed progress write must not interrupt reading.
    }
  }
}

class _ComicPageControls extends StatelessWidget {
  const _ComicPageControls({
    required this.currentPage,
    required this.pageCount,
    required this.onPageSelected,
    required this.onPrevious,
    required this.onNext,
    required this.doublePage,
  });

  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool doublePage;

  @override
  Widget build(BuildContext context) {
    final canGoBack = currentPage > 0;
    final lastVisiblePage = doublePage && currentPage > 0
        ? (currentPage + 1).clamp(0, pageCount - 1)
        : currentPage;
    final canGoForward = lastVisiblePage < pageCount - 1;
    final pageLabel = lastVisiblePage == currentPage
        ? '${currentPage + 1} / $pageCount'
        : '${currentPage + 1}–${lastVisiblePage + 1} / $pageCount';
    return SafeArea(
      top: false,
      child: Material(
        color: const Color(0xFF161616),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: canGoBack ? onPrevious : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Slider(
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
              Text(pageLabel),
              IconButton(
                tooltip: 'Next page',
                onPressed: canGoForward ? onNext : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
        for (final pageIndex in pageIndexes)
          Expanded(
            child: _ComicImage(session: session, pageIndex: pageIndex),
          ),
      ],
    );
  }
}

class _ComicImage extends StatelessWidget {
  const _ComicImage({required this.session, required this.pageIndex});

  final ComicReaderSession session;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: session.readPage(pageIndex),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ReaderErrorView(error: snapshot.error!);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Image.memory(snapshot.data!, fit: BoxFit.contain),
          ),
        );
      },
    );
  }
}

Future<void> _showComicReadingSettings(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      var preferences =
          ref.read(comicReadingPreferencesProvider).asData?.value ??
          ComicReadingPreferences.defaults;
      return StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> update(ComicReadingPreferences next) async {
            setModalState(() => preferences = next);
            await ref
                .read(comicReadingPreferencesRepositoryProvider)
                .save(next);
            ref.invalidate(comicReadingPreferencesProvider);
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comic reading settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownMenu<ComicReadingMode>(
                    initialSelection: preferences.mode,
                    label: const Text('Reading mode'),
                    dropdownMenuEntries: [
                      for (final mode in ComicReadingMode.values)
                        DropdownMenuEntry(value: mode, label: _modeLabel(mode)),
                    ],
                    onSelected: (value) {
                      if (value != null) {
                        update(preferences.copyWith(mode: value));
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Double-page spread'),
                    subtitle: Text(
                      preferences.mode == ComicReadingMode.vertical
                          ? 'Available in horizontal reading modes.'
                          : 'Keep the cover single, then pair following pages.',
                    ),
                    value: preferences.doublePage,
                    onChanged: preferences.mode == ComicReadingMode.vertical
                        ? null
                        : (value) =>
                              update(preferences.copyWith(doublePage: value)),
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

String _modeLabel(ComicReadingMode mode) {
  return switch (mode) {
    ComicReadingMode.leftToRight => 'Left to right',
    ComicReadingMode.rightToLeft => 'Right to left',
    ComicReadingMode.vertical => 'Vertical paging',
  };
}

class _ReaderErrorView extends StatelessWidget {
  const _ReaderErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Unable to open this publication.\n$error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
