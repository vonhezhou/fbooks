import 'dart:async';

import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/reader/text_reader_session.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
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
    ref
        .watch(readingProgressProvider(widget.publicationId))
        .whenData(_restorePosition);
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.session.document.chapters.length,
      onPageChanged: _savePosition,
      itemBuilder: (context, index) {
        return _TextChapterView(
          chapter: widget.session.document.chapters[index],
        );
      },
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
    final chapterIndex = locator.chapterIndex.clamp(0, lastChapter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(chapterIndex);
      }
    });
  }

  void _savePosition(int chapterIndex) {
    unawaited(_persistPosition(chapterIndex));
  }

  Future<void> _persistPosition(int chapterIndex) async {
    try {
      await ref
          .read(readingProgressRepositoryProvider)
          .save(
            ReadingProgress(
              publicationId: widget.publicationId,
              locator: TextOffsetLocator(chapterIndex: chapterIndex, offset: 0),
              updatedAt: DateTime.now(),
            ),
          );
    } catch (_) {
      // A failed progress write must not interrupt reading.
    }
  }
}

class _TextChapterView extends StatelessWidget {
  const _TextChapterView({required this.chapter});

  final TextChapter chapter;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              chapter.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Text(chapter.text, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
