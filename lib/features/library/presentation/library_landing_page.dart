import 'package:fbooks/app/providers.dart';
import 'package:fbooks/domain/publication/publication.dart';
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

class _PublicationList extends StatelessWidget {
  const _PublicationList({required this.publications});

  final List<Publication> publications;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: publications.length,
      itemBuilder: (context, index) {
        final publication = publications[index];
        return ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(publication.title),
          subtitle: Text(
            publication.authors.isEmpty
                ? publication.source.name
                : publication.authors.join(', '),
          ),
          trailing: Text(publication.format.name),
          onTap: switch (publication.format) {
            PublicationFormat.comicArchive => () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => ComicReaderPage(
                    publicationId: publication.id,
                    title: publication.title,
                  ),
                ),
              );
            },
            PublicationFormat.epub || PublicationFormat.text => () {
              Navigator.of(context).push(
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
}
