import 'package:fbooks/app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fbooks currently ships integrations as built-in, reviewed capabilities.
/// This page makes that boundary explicit instead of presenting an empty stub.
class PluginsPage extends ConsumerWidget {
  const PluginsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceCount =
        ref.watch(libraryPublicationsProvider).asData?.value.length ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
      children: [
        Text(
          'Plugins',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Built-in capabilities are reviewed and run locally with your library.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 28),
        _CapabilityCard(
          icon: Icons.folder_open_outlined,
          title: 'Local files',
          description:
              'Import and read CBZ, EPUB, and TXT files stored on this device.',
          status: 'Enabled',
          detail: '$sourceCount books in your local library',
        ),
        const SizedBox(height: 14),
        const _CapabilityCard(
          icon: Icons.cloud_outlined,
          title: 'OPDS catalogues',
          description: 'Browse OPDS 1 and OPDS 2 catalogues and add readable titles to the library.',
          status: 'Enabled',
          detail: 'Configure catalogues from the Library toolbar',
        ),
        const SizedBox(height: 14),
        const _CapabilityCard(
          icon: Icons.extension_outlined,
          title: 'Third-party extensions',
          description: 'No external extensions are installed. Fbooks does not load unreviewed reader code.',
          status: 'Not available',
          detail: 'A plug-in API is deliberately outside the current local-first milestone',
          enabled: false,
        ),
      ],
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.detail,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final String status;
  final String detail;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: enabled
                ? Theme.of(context).colorScheme.secondaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundColor: enabled
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
            child: Icon(icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Chip(label: Text(status)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(description),
                const SizedBox(height: 8),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
