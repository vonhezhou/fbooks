import 'package:fbooks/app/providers.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/features/opds/presentation/opds_catalog_page.dart';
import 'package:fbooks/features/reader/presentation/comic_reader_page.dart';
import 'package:fbooks/features/reader/presentation/text_reader_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LibraryLandingPage extends ConsumerStatefulWidget {
  const LibraryLandingPage({super.key});

  @override
  ConsumerState<LibraryLandingPage> createState() => _LibraryLandingPageState();
}

class _LibraryLandingPageState extends ConsumerState<LibraryLandingPage> {
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fbooks'),
        actions: [
          IconButton(
            tooltip: 'Add local publications',
            onPressed: _isImporting ? null : _importLocalPublications,
            icon: _isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            tooltip: 'Connect OPDS catalog',
            onPressed: _connectOpdsCatalog,
            icon: const Icon(Icons.add_to_queue_outlined),
          ),
          IconButton(
            tooltip: 'Browse OPDS catalogs',
            onPressed: _showOpdsCatalogs,
            icon: const Icon(Icons.cloud_outlined),
          ),
        ],
      ),
      body: ref
          .watch(libraryPublicationsProvider)
          .when(
            data: (publications) => publications.isEmpty
                ? const _EmptyLibraryView()
                : _PublicationList(publications: publications),
            error: (error, stackTrace) =>
                Center(child: Text('Unable to load the library: $error')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
    );
  }

  Future<void> _importLocalPublications() async {
    setState(() => _isImporting = true);
    try {
      final candidates = await ref.read(localPublicationPickerProvider).pick();
      if (candidates.isEmpty || !mounted) {
        return;
      }

      final result = await ref
          .read(localPublicationImporterProvider)
          .importCandidates(candidates);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.imported.length} added, '
            '${result.duplicates.length} already in library, '
            '${result.unsupported.length} unsupported.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add publications: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _connectOpdsCatalog() async {
    final controller = TextEditingController();
    final endpointText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect OPDS catalog'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://example.com/opds',
            labelText: 'Catalog URL',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (endpointText == null || !mounted) {
      return;
    }

    final endpoint = Uri.tryParse(endpointText.trim());
    if (endpoint == null ||
        !endpoint.hasAuthority ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid HTTP(S) catalog URL.')),
      );
      return;
    }

    await ref
        .read(librarySourceRepositoryProvider)
        .save(
          LibrarySource(
            id: 'opds:$endpoint',
            kind: LibrarySourceKind.opds,
            name: endpoint.host,
            endpoint: endpoint,
          ),
        );
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OpdsCatalogPage(endpoint: endpoint),
      ),
    );
  }

  Future<void> _showOpdsCatalogs() async {
    final sources = await ref
        .read(librarySourceRepositoryProvider)
        .listSources();
    final opdsSources = sources
        .where((source) => source.kind == LibrarySourceKind.opds)
        .toList();
    if (!mounted) {
      return;
    }
    if (opdsSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No OPDS catalogs connected yet.')),
      );
      return;
    }

    final endpoint = await showModalBottomSheet<Uri>(
      context: context,
      builder: (context) => ListView(
        children: [
          const ListTile(title: Text('OPDS catalogs')),
          for (final source in opdsSources)
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(source.name),
              subtitle: Text(source.endpoint.toString()),
              onTap: () => Navigator.of(context).pop(source.endpoint),
            ),
        ],
      ),
    );
    if (endpoint == null || !mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OpdsCatalogPage(endpoint: endpoint),
      ),
    );
  }
}

class _EmptyLibraryView extends StatelessWidget {
  const _EmptyLibraryView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 64),
            SizedBox(height: 16),
            Text(
              'Your library will appear here.',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 8),
            Text(
              'Start by importing a local publication or connecting an OPDS source.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicationList extends ConsumerWidget {
  const _PublicationList({required this.publications});

  final List<Publication> publications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      itemCount: publications.length,
      itemBuilder: (context, index) {
        final publication = publications[index];
        final progress = ref.watch(readingProgressProvider(publication.id));
        return ListTile(
          leading: Icon(_iconFor(publication.format)),
          title: Text(publication.title),
          subtitle: _PublicationSubtitle(
            publication: publication,
            progress: progress.asData?.value,
          ),
          trailing: Text(_formatLabel(publication.format)),
          onTap: switch (publication.format) {
            PublicationFormat.comicArchive => () {
              _openReader(
                context,
                ref,
                publication.id,
                MaterialPageRoute<void>(
                  builder: (context) => ComicReaderPage(
                    publicationId: publication.id,
                    title: publication.title,
                  ),
                ),
              );
            },
            PublicationFormat.epub || PublicationFormat.text => () {
              _openReader(
                context,
                ref,
                publication.id,
                MaterialPageRoute<void>(
                  builder: (context) => TextReaderPage(
                    publicationId: publication.id,
                    title: publication.title,
                  ),
                ),
              );
            },
            _ => null,
          },
        );
      },
      separatorBuilder: (context, index) => const Divider(height: 1),
    );
  }

  Future<void> _openReader(
    BuildContext context,
    WidgetRef ref,
    PublicationId publicationId,
    Route<void> route,
  ) async {
    await Navigator.of(context).push(route);
    ref.invalidate(readingProgressProvider(publicationId));
  }

  IconData _iconFor(PublicationFormat format) {
    return switch (format) {
      PublicationFormat.comicArchive ||
      PublicationFormat.comicDirectory => Icons.auto_stories_outlined,
      PublicationFormat.epub ||
      PublicationFormat.text => Icons.menu_book_outlined,
      PublicationFormat.pdf => Icons.picture_as_pdf_outlined,
    };
  }

  String _formatLabel(PublicationFormat format) {
    return switch (format) {
      PublicationFormat.comicArchive => 'CBZ',
      PublicationFormat.comicDirectory => 'Comic',
      PublicationFormat.epub => 'EPUB',
      PublicationFormat.pdf => 'PDF',
      PublicationFormat.text => 'TXT',
    };
  }
}

class _PublicationSubtitle extends StatelessWidget {
  const _PublicationSubtitle({
    required this.publication,
    required this.progress,
  });

  final Publication publication;
  final ReadingProgress? progress;

  @override
  Widget build(BuildContext context) {
    final attribution = publication.authors.isEmpty
        ? publication.source.name
        : publication.authors.join(', ');
    final resumeLabel = switch (progress?.locator) {
      ComicPageLocator(:final pageIndex) => 'Resume at page ${pageIndex + 1}',
      TextOffsetLocator(:final chapterIndex) =>
        'Resume at chapter ${chapterIndex + 1}',
      EpubCfiLocator() => 'Resume reading',
      null => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(attribution),
        if (resumeLabel != null)
          Text(
            resumeLabel,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
      ],
    );
  }
}
