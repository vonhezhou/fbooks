import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/reader/text_reader_session.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
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
        data: (value) => _TextChapterPager(session: value),
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

class _TextChapterPager extends StatelessWidget {
  const _TextChapterPager({required this.session});

  final TextReaderSession session;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      itemCount: session.document.chapters.length,
      itemBuilder: (context, index) {
        return _TextChapterView(chapter: session.document.chapters[index]);
      },
    );
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
