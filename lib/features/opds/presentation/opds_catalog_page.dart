import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/opds/opds_catalog.dart';
import 'package:fbooks/application/opds/opds_acquisition_importer.dart';
import 'package:fbooks/application/opds/opds_catalog_request.dart';
import 'package:fbooks/application/opds/opds_credentials.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OpdsCatalogPage extends ConsumerWidget {
  const OpdsCatalogPage({super.key, required this.source, this.endpoint});

  final LibrarySource source;
  final Uri? endpoint;

  Uri get _endpoint => endpoint ?? source.endpoint!;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(
      opdsCatalogProvider(
        OpdsCatalogRequest(sourceId: source.id, endpoint: _endpoint),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(source.name),
        actions: [
          IconButton(
            tooltip: 'Retry catalog',
            onPressed: () => ref.invalidate(
              opdsCatalogProvider(
                OpdsCatalogRequest(sourceId: source.id, endpoint: _endpoint),
              ),
            ),
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<_CatalogAction>(
            tooltip: 'Catalog actions',
            onSelected: (action) => switch (action) {
              _CatalogAction.edit => _editCatalog(context, ref, source),
              _CatalogAction.remove => _removeCatalog(context, ref, source),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _CatalogAction.edit,
                child: Text('Edit catalog'),
              ),
              PopupMenuItem(
                value: _CatalogAction.remove,
                child: Text('Remove catalog'),
              ),
            ],
          ),
        ],
      ),
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
                        builder: (context) => OpdsCatalogPage(
                          source: source,
                          endpoint: link.href,
                        ),
                      ),
                    );
                  },
                ),
              const Divider(),
            ],
            ListTile(title: Text(value.title)),
            for (final publication in value.publications)
              _OpdsPublicationTile(source: source, publication: publication),
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

enum _CatalogAction { edit, remove }

Future<void> _editCatalog(
  BuildContext context,
  WidgetRef ref,
  LibrarySource source,
) async {
  final existingCredentials = await ref
      .read(opdsCredentialsRepositoryProvider)
      .load(source.id);
  if (!context.mounted) {
    return;
  }
  final endpointController = TextEditingController(
    text: source.endpoint.toString(),
  );
  final usernameController = TextEditingController(
    text: existingCredentials?.username,
  );
  final passwordController = TextEditingController(
    text: existingCredentials?.password,
  );
  final save = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit OPDS catalog'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: endpointController,
              decoration: const InputDecoration(labelText: 'Catalog URL'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password (optional)',
              ),
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  final endpointText = endpointController.text.trim();
  final username = usernameController.text.trim();
  final password = passwordController.text;
  endpointController.dispose();
  usernameController.dispose();
  passwordController.dispose();
  if (!context.mounted || save != true) {
    return;
  }
  final endpoint = Uri.tryParse(endpointText);
  if (endpoint == null ||
      !endpoint.hasAuthority ||
      (endpoint.scheme != 'http' && endpoint.scheme != 'https') ||
      (username.isNotEmpty != password.isNotEmpty)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter a valid URL and both credentials.')),
    );
    return;
  }
  final updated = LibrarySource(
    id: source.id,
    kind: source.kind,
    name: endpoint.host,
    endpoint: endpoint,
  );
  await ref.read(librarySourceRepositoryProvider).save(updated);
  if (username.isEmpty) {
    await ref.read(opdsCredentialsRepositoryProvider).delete(source.id);
  } else {
    await ref
        .read(opdsCredentialsRepositoryProvider)
        .save(
          source.id,
          OpdsCredentials(username: username, password: password),
        );
  }
  if (!context.mounted) {
    return;
  }
  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (context) => OpdsCatalogPage(source: updated),
    ),
  );
}

Future<void> _removeCatalog(
  BuildContext context,
  WidgetRef ref,
  LibrarySource source,
) async {
  final publications = await ref
      .read(publicationRepositoryProvider)
      .listPublications();
  if (!context.mounted) {
    return;
  }
  if (publications.any((publication) => publication.source.id == source.id)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Remove this catalog’s downloaded publications first.'),
      ),
    );
    return;
  }
  final remove = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove catalog?'),
      content: Text(
        '“${source.name}” and its saved credentials will be removed.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (!context.mounted || remove != true) {
    return;
  }
  await ref.read(librarySourceRepositoryProvider).delete(source.id);
  await ref.read(opdsCredentialsRepositoryProvider).delete(source.id);
  if (context.mounted) {
    Navigator.of(context).pop();
  }
}

class _OpdsPublicationTile extends ConsumerStatefulWidget {
  const _OpdsPublicationTile({required this.source, required this.publication});

  final LibrarySource source;
  final OpdsPublication publication;

  @override
  ConsumerState<_OpdsPublicationTile> createState() =>
      _OpdsPublicationTileState();
}

class _OpdsPublicationTileState extends ConsumerState<_OpdsPublicationTile> {
  bool _isDownloading = false;
  OpdsDownloadCancellation? _cancellation;
  double? _downloadFraction;

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
          : _isDownloading
          ? IconButton(
              tooltip: 'Cancel download',
              onPressed: _cancellation?.cancel,
              icon: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: _downloadFraction,
                  strokeWidth: 2,
                ),
              ),
            )
          : IconButton(
              tooltip: 'Download to library or refresh metadata',
              onPressed: () => _download(acquisition),
              icon: const Icon(Icons.download_outlined),
            ),
    );
  }

  Future<void> _download(OpdsAcquisition acquisition) async {
    final cancellation = OpdsDownloadCancellation();
    setState(() {
      _isDownloading = true;
      _cancellation = cancellation;
      _downloadFraction = null;
    });
    try {
      final publication = await ref
          .read(opdsAcquisitionImporterProvider)
          .acquire(
            source: widget.source,
            publication: widget.publication,
            acquisition: acquisition,
            cancellation: cancellation,
            onProgress: (progress) {
              if (mounted) {
                setState(() => _downloadFraction = progress.fraction);
              }
            },
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${publication.title} added to the library.')),
      );
    } on OpdsDownloadCancelled {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Download cancelled.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to download publication: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _cancellation = null;
          _downloadFraction = null;
        });
      }
    }
  }
}
