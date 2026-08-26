import 'package:fbooks/app/providers.dart';
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
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(publication.title),
                subtitle: Text(
                  publication.authors.isEmpty
                      ? 'No author metadata'
                      : publication.authors.join(', '),
                ),
                trailing: publication.acquisitions.isEmpty
                    ? null
                    : const Icon(Icons.download_outlined),
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
