import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/opds/opds_catalog.dart';
import 'package:fbooks/application/opds/opds_acquisition_importer.dart';
import 'package:fbooks/application/opds/opds_catalog_request.dart';
import 'package:fbooks/application/opds/opds_credentials.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
class OpdsCatalogPage extends ConsumerWidget {
  const OpdsCatalogPage({super.key, required this.source, this.endpoint});

  final LibrarySource source;
  final Uri? endpoint;

  Uri get _endpoint => endpoint ?? source.endpoint!;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
            tooltip: l10n.opdsRetryCatalog,
            onPressed: () => ref.invalidate(
              opdsCatalogProvider(
                OpdsCatalogRequest(sourceId: source.id, endpoint: _endpoint),
              ),
            ),
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<_CatalogAction>(
            tooltip: l10n.opdsCatalogActions,
            onSelected: (action) => switch (action) {
              _CatalogAction.edit => _editCatalog(context, ref, source),
              _CatalogAction.remove => _removeCatalog(context, ref, source),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _CatalogAction.edit,
                child: Text(l10n.editCatalog),
              ),
              PopupMenuItem(
                value: _CatalogAction.remove,
                child: Text(l10n.removeCatalog),
              ),
            ],
          ),
        ],
      ),
      body: catalog.when(
        data: (value) => ListView(
          children: [
            if (value.navigation.isNotEmpty) ...[
              ListTile(title: Text(l10n.browse)),
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
              l10n.unableToLoadOpdsCatalog(error.toString()),
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
  final l10n = AppLocalizations.of(context);
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
      title: Text(l10n.editOpdsCatalog),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: endpointController,
              decoration: InputDecoration(labelText: l10n.catalogUrl),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: usernameController,
              decoration: InputDecoration(labelText: l10n.usernameOptional),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: l10n.passwordOptional),
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.save),
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
      SnackBar(content: Text(l10n.validCatalogCredentialsRequired)),
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
  final l10n = AppLocalizations.of(context);
  final publications = await ref
      .read(publicationRepositoryProvider)
      .listPublications();
  if (!context.mounted) {
    return;
  }
  if (publications.any((publication) => publication.source.id == source.id)) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.catalogHasPublications)));
    return;
  }
  final remove = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.removeCatalogTitle),
      content: Text(l10n.removeCatalogDescription(source.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.remove),
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
    final l10n = AppLocalizations.of(context);
    final acquisition = widget.publication.acquisitions.firstOrNull;
    return ListTile(
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(widget.publication.title),
      subtitle: Text(
        widget.publication.authors.isEmpty
            ? l10n.noAuthorMetadata
            : widget.publication.authors.join(', '),
      ),
      trailing: acquisition == null
          ? null
          : _isDownloading
          ? IconButton(
              tooltip: l10n.cancelDownload,
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
              tooltip: l10n.downloadToLibrary,
              onPressed: () => _download(acquisition),
              icon: const Icon(Icons.download_outlined),
            ),
    );
  }

  Future<void> _download(OpdsAcquisition acquisition) async {
    final l10n = AppLocalizations.of(context);
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
        SnackBar(
          content: Text(l10n.publicationAddedToLibrary(publication.title)),
        ),
      );
    } on OpdsDownloadCancelled {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.downloadCancelled)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.unableToDownloadPublication(error.toString())),
        ),
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
