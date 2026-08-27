import 'dart:async';
import 'dart:typed_data';

import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/reader/comic_reader_session.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(title)),
      body: session.when(
        data: (value) =>
            _ComicPageView(publicationId: publicationId, session: value),
        error: (error, stackTrace) => _ReaderErrorView(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ComicPageView extends ConsumerStatefulWidget {
  const _ComicPageView({required this.publicationId, required this.session});

  final PublicationId publicationId;
  final ComicReaderSession session;

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
  Widget build(BuildContext context) {
    final progress = ref.watch(readingProgressProvider(widget.publicationId));
    progress.whenData(_restorePosition);
    final pageCount = widget.session.document.pages.length;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: pageCount,
            onPageChanged: _savePosition,
            itemBuilder: (context, index) {
              return _ComicImage(session: widget.session, pageIndex: index);
            },
          ),
        ),
        _ComicPageControls(
          currentPage: _currentPage,
          pageCount: pageCount,
          onPageSelected: _goToPage,
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
        _pageController.jumpToPage(pageIndex);
        setState(() => _currentPage = pageIndex);
      }
    });
  }

  void _savePosition(int pageIndex) {
    setState(() => _currentPage = pageIndex);
    unawaited(_persistPosition(pageIndex));
  }

  Future<void> _goToPage(int pageIndex) async {
    if (!_pageController.hasClients || pageIndex == _currentPage) {
      return;
    }
    await _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
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
  });

  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    final canGoBack = currentPage > 0;
    final canGoForward = currentPage < pageCount - 1;
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
                onPressed: canGoBack
                    ? () => onPageSelected(currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Slider(
                  value: currentPage.toDouble(),
                  min: 0,
                  max: (pageCount - 1).toDouble(),
                  divisions: pageCount > 1 ? pageCount - 1 : null,
                  label: '${currentPage + 1} / $pageCount',
                  onChanged: pageCount > 1
                      ? (value) => onPageSelected(value.round())
                      : null,
                ),
              ),
              Text('${currentPage + 1} / $pageCount'),
              IconButton(
                tooltip: 'Next page',
                onPressed: canGoForward
                    ? () => onPageSelected(currentPage + 1)
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
