import 'package:fbooks/app/providers.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/features/reader/presentation/comic_reader_page.dart';
import 'package:fbooks/features/reader/presentation/text_reader_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Displays the metadata and saved reading state for a library publication.
class PublicationDetailsPage extends ConsumerWidget {
  const PublicationDetailsPage({super.key, required this.publication});

  final Publication publication;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(readingProgressProvider(publication.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Publication details')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          children: [
            Center(child: _PublicationCover(publication: publication)),
            const SizedBox(height: 28),
            Text(
              publication.title,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              publication.authors.isEmpty
                  ? 'Unknown author'
                  : publication.authors.join(', '),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isReadable(publication)
                  ? () => _openReader(context, publication)
                  : null,
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(
                progress.asData?.value == null
                    ? 'Start reading'
                    : 'Continue reading',
              ),
            ),
            const SizedBox(height: 28),
            Text('ABOUT', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _DetailsCard(
              children: [
                _DetailRow(
                  label: 'Format',
                  value: _formatLabel(publication.format),
                ),
                _DetailRow(label: 'Source', value: _sourceLabel(publication)),
                _DetailRow(
                  label: 'Last reading position',
                  value: progress.when(
                    data: _readingPositionLabel,
                    loading: () => 'Loading…',
                    error: (_, _) => 'Unavailable',
                  ),
                ),
              ],
            ),
            if (publication.description case final description?) ...[
              const SizedBox(height: 28),
              Text(
                'DESCRIPTION',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              _DetailsCard(children: [Text(description)]),
            ],
          ],
        ),
      ),
    );
  }
}

class _PublicationCover extends StatelessWidget {
  const _PublicationCover({required this.publication});

  final Publication publication;

  @override
  Widget build(BuildContext context) {
    final coverUri = publication.coverUri;
    final canLoadCover =
        coverUri != null &&
        (coverUri.scheme == 'http' || coverUri.scheme == 'https');
    return Container(
      width: 184,
      height: 260,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _coverColor(publication.format),
        borderRadius: BorderRadius.circular(16),
      ),
      child: canLoadCover
          ? Image.network(
              coverUri.toString(),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _CoverFallback(format: publication.format),
            )
          : _CoverFallback(format: publication.format),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.format});

  final PublicationFormat format;

  @override
  Widget build(BuildContext context) =>
      Center(child: Icon(_formatIcon(format), size: 58, color: Colors.white));
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(children: children),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

bool _isReadable(Publication publication) => switch (publication.format) {
  PublicationFormat.comicArchive ||
  PublicationFormat.epub ||
  PublicationFormat.text => true,
  PublicationFormat.comicDirectory || PublicationFormat.pdf => false,
};

void _openReader(BuildContext context, Publication publication) {
  final route = switch (publication.format) {
    PublicationFormat.comicArchive => MaterialPageRoute<void>(
      builder: (context) => ComicReaderPage(
        publicationId: publication.id,
        title: publication.title,
      ),
    ),
    PublicationFormat.epub || PublicationFormat.text => MaterialPageRoute<void>(
      builder: (context) => TextReaderPage(
        publicationId: publication.id,
        title: publication.title,
      ),
    ),
    PublicationFormat.comicDirectory || PublicationFormat.pdf => null,
  };
  if (route != null) {
    Navigator.of(context).push(route);
  }
}

String _formatLabel(PublicationFormat format) => switch (format) {
  PublicationFormat.comicArchive => 'CBZ comic',
  PublicationFormat.comicDirectory => 'Comic directory',
  PublicationFormat.epub => 'EPUB ebook',
  PublicationFormat.pdf => 'PDF document',
  PublicationFormat.text => 'Plain text',
};

String _sourceLabel(Publication publication) {
  final endpoint = publication.source.endpoint;
  return endpoint == null
      ? publication.source.name
      : '${publication.source.name} · ${endpoint.host}';
}

String _readingPositionLabel(ReadingProgress? progress) =>
    switch (progress?.locator) {
      ComicPageLocator(:final pageIndex) => 'Page ${pageIndex + 1}',
      TextOffsetLocator(:final chapterIndex) => 'Chapter ${chapterIndex + 1}',
      EpubCfiLocator() => 'Resume reading',
      null => 'Not opened yet',
    };

IconData _formatIcon(PublicationFormat format) => switch (format) {
  PublicationFormat.comicArchive ||
  PublicationFormat.comicDirectory => Icons.auto_stories_outlined,
  PublicationFormat.epub || PublicationFormat.text => Icons.menu_book_outlined,
  PublicationFormat.pdf => Icons.picture_as_pdf_outlined,
};

Color _coverColor(PublicationFormat format) => switch (format) {
  PublicationFormat.comicArchive ||
  PublicationFormat.comicDirectory => const Color(0xFF455A64),
  PublicationFormat.epub => const Color(0xFF6D597A),
  PublicationFormat.text => const Color(0xFF5B7C6F),
  PublicationFormat.pdf => const Color(0xFF9B3D3D),
};
