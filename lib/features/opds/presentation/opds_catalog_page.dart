import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/opds/opds_catalog.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OpdsCatalogPage extends ConsumerWidget {
  const OpdsCatalogPage({super.key, required this.endpoint});

  final Uri endpoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(opdsCatalogProvider(endpoint));
    return Scaffold(
      appBar: AppBar(title: Text(endpoint.host)),
      body: catalog.when(
        data: (value) => ListView(
          children: [
            if (value.navigation.isNotEmpty) ...[
              const ListTile(title: Text('Browse')),
              for (final link in value.navigation)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(link.title),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            OpdsCatalogPage(endpoint: link.href),
                      ),
                    );
                  },
                ),
              const Divider(),
            ],
            ListTile(title: Text(value.title)),
            for (final publication in value.publications)
              _OpdsPublicationTile(
                endpoint: endpoint,
                publication: publication,
              ),
          ],
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load the OPDS catalog.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _OpdsPublicationTile extends ConsumerStatefulWidget {
  const _OpdsPublicationTile({
    required this.endpoint,
    required this.publication,
  });

  final Uri endpoint;
  final OpdsPublication publication;

  @override
  ConsumerState<_OpdsPublicationTile> createState() =>
      _OpdsPublicationTileState();
}

class _OpdsPublicationTileState extends ConsumerState<_OpdsPublicationTile> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final acquisition = widget.publication.acquisitions.firstOrNull;
    return ListTile(
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(widget.publication.title),
      subtitle: Text(
        widget.publication.authors.isEmpty
            ? 'No author metadata'
            : widget.publication.authors.join(', '),
      ),
      trailing: acquisition == null
          ? null
          : IconButton(
              tooltip: 'Download to library',
              onPressed: _isDownloading ? null : () => _download(acquisition),
              icon: _isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
            ),
    );
  }

  Future<void> _download(OpdsAcquisition acquisition) async {
    setState(() => _isDownloading = true);
    try {
      final publication = await ref
          .read(opdsAcquisitionImporterProvider)
          .acquire(
            source: LibrarySource(
              id: 'opds:${widget.endpoint}',
              kind: LibrarySourceKind.opds,
              name: widget.endpoint.host,
              endpoint: widget.endpoint,
            ),
            publication: widget.publication,
            acquisition: acquisition,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${publication.title} added to the library.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to download publication: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }
}
