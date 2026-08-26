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
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.session.document.pages.length,
      onPageChanged: _savePosition,
      itemBuilder: (context, index) {
        return _ComicImage(session: widget.session, pageIndex: index);
      },
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
    final pageIndex = locator.pageIndex.clamp(0, lastPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(pageIndex);
      }
    });
  }

  void _savePosition(int pageIndex) {
    unawaited(_persistPosition(pageIndex));
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
