import 'package:fbooks/app/providers.dart';
import 'package:fbooks/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
      children: [
        Text(
          l10n.plugins,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.pluginsDescription,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 28),
        _CapabilityCard(
          icon: Icons.folder_open_outlined,
          title: l10n.localFilesPluginTitle,
          description: l10n.localFilesDescription,
          status: l10n.enabled,
          detail: l10n.localLibraryBookCount(sourceCount),
        ),
        const SizedBox(height: 14),
        _CapabilityCard(
          icon: Icons.cloud_outlined,
          title: l10n.opdsCatalogues,
          description: l10n.opdsCataloguesDescription,
          status: l10n.enabled,
          detail: l10n.configureCatalogues,
        ),
        const SizedBox(height: 14),
        _CapabilityCard(
          icon: Icons.extension_outlined,
          title: l10n.thirdPartyExtensions,
          description: l10n.thirdPartyExtensionsDescription,
          status: l10n.notAvailable,
          detail: l10n.thirdPartyExtensionsDetail,
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
