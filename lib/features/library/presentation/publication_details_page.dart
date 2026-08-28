import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/library/library_publication_remover.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/features/reader/presentation/comic_reader_page.dart';
import 'package:fbooks/features/reader/presentation/pdf_reader_page.dart';
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
      appBar: AppBar(
        title: const Text('Publication details'),
        actions: [
          if (publication.source.kind == LibrarySourceKind.local)
            IconButton(
              tooltip: 'Repair local file',
              onPressed: () => _repairLocalFile(context, ref, publication),
              icon: const Icon(Icons.build_outlined),
            ),
          IconButton(
            tooltip: 'Remove from library',
            onPressed: () => _confirmRemoval(context, ref, publication),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => _PublicationDetailsContent(
          publication: publication,
          progress: progress,
          desktop: constraints.maxWidth >= 960,
        ),
      ),
    );
  }
}

class _PublicationDetailsContent extends StatelessWidget {
  const _PublicationDetailsContent({
    required this.publication,
    required this.progress,
    required this.desktop,
  });

  final Publication publication;
  final AsyncValue<ReadingProgress?> progress;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      publication.title,
      style: Theme.of(context).textTheme.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    );
    final author = Text(
      publication.authors.isEmpty
          ? 'Unknown author'
          : publication.authors.join(', '),
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    final readingAction = FilledButton.icon(
      onPressed: _isReadable(publication)
          ? () => _openReader(context, publication)
          : null,
      icon: const Icon(Icons.menu_book_outlined),
      label: Text(
        progress.asData?.value == null ? 'Start reading' : 'Continue reading',
      ),
    );
    final details = _DetailsCard(
      children: [
        _DetailRow(label: 'Format', value: _formatLabel(publication.format)),
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
    );
    final description = publication.description;

    if (!desktop) {
      return SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          children: [
            Center(child: _PublicationCover(publication: publication)),
            const SizedBox(height: 28),
            title,
            const SizedBox(height: 8),
            author,
            const SizedBox(height: 24),
            readingAction,
            const SizedBox(height: 28),
            Text('ABOUT', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            details,
            if (description != null) ...[
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
      );
    }

    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          key: const Key('publication-details-desktop-content'),
          constraints: const BoxConstraints(maxWidth: 1080),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(48, 40, 48, 56),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PublicationCover(publication: publication, desktop: true),
                  const SizedBox(width: 40),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: 8),
                          author,
                          const SizedBox(height: 28),
                          SizedBox(width: 220, child: readingAction),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text('ABOUT', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              details,
              if (description != null) ...[
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
      ),
    );
  }
}

Future<void> _repairLocalFile(
  BuildContext context,
  WidgetRef ref,
  Publication publication,
) async {
  final replacement = await ref
      .read(localPublicationPickerProvider)
      .pickReplacement(publication.format);
  if (!context.mounted || replacement == null) {
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(localPublicationRepairerProvider)
        .repair(publicationId: publication.id, replacement: replacement);
    if (!context.mounted) {
      return;
    }
    ref.invalidate(comicReaderSessionProvider(publication.id));
    ref.invalidate(textReaderSessionProvider(publication.id));
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('“${publication.title}” now uses the selected file.'),
      ),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Unable to repair local file: $error')),
    );
  }
}

Future<void> _confirmRemoval(
  BuildContext context,
  WidgetRef ref,
  Publication publication,
) async {
  final downloadFiles = managedDownloadFiles(publication);
  final deleteDownload = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove from library?'),
      content: Text(
        downloadFiles.isEmpty
            ? '“${publication.title}” will be removed from Fbooks, all collections, and saved reading progress. Its original local file will stay on your device.'
            : '“${publication.title}” will be removed from Fbooks, all collections, and saved reading progress. Choose whether to keep its downloaded file.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (downloadFiles.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Remove and keep download'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(downloadFiles.isNotEmpty),
          child: Text(
            downloadFiles.isEmpty
                ? 'Remove from library'
                : 'Remove and delete download',
          ),
        ),
      ],
    ),
  );
  if (!context.mounted || deleteDownload == null) {
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await ref
        .read(libraryPublicationRemoverProvider)
        .remove(publication.id, deleteManagedFiles: deleteDownload);
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.filesNotDeleted.isEmpty
              ? '“${publication.title}” was removed from the library.'
              : '“${publication.title}” was removed, but its downloaded file could not be deleted.',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Unable to remove publication: $error')),
    );
  }
}

class _PublicationCover extends StatelessWidget {
  const _PublicationCover({required this.publication, this.desktop = false});

  final Publication publication;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final coverUri = publication.coverUri;
    final canLoadCover =
        coverUri != null &&
        (coverUri.scheme == 'http' || coverUri.scheme == 'https');
    return Container(
      width: desktop ? 230 : 184,
      height: desktop ? 326 : 260,
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
  PublicationFormat.pdf ||
  PublicationFormat.text => true,
  PublicationFormat.comicDirectory => false,
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
    PublicationFormat.pdf => MaterialPageRoute<void>(
      builder: (context) => PdfReaderPage(
        publicationId: publication.id,
        title: publication.title,
      ),
    ),
    PublicationFormat.comicDirectory => null,
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
      PdfPageLocator(:final pageNumber) => 'Page $pageNumber',
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
