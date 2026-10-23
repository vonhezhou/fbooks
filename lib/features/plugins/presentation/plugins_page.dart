import 'package:fbooks/app/providers.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fbooks currently ships integrations as built-in, reviewed capabilities.
/// This page makes that boundary explicit instead of presenting an empty stub.
class PluginsPage extends ConsumerStatefulWidget {
  const PluginsPage({super.key});

  @override
  ConsumerState<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends ConsumerState<PluginsPage> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final sourceCount =
        ref.watch(libraryPublicationsProvider).asData?.value.length ?? 0;
    final l10n = AppLocalizations.of(context);
    final capabilities = [
      _CapabilityCard(
        icon: Icons.folder_open_outlined,
        title: l10n.localFilesPluginTitle,
        description: l10n.localFilesDescription,
        status: l10n.enabled,
        detail: l10n.localLibraryBookCount(sourceCount),
      ),
      _CapabilityCard(
        icon: Icons.cloud_outlined,
        title: l10n.opdsCatalogues,
        description: l10n.opdsCataloguesDescription,
        status: l10n.enabled,
        detail: l10n.configureCatalogues,
      ),
      _CapabilityCard(
        icon: Icons.extension_outlined,
        title: l10n.thirdPartyExtensions,
        description: l10n.thirdPartyExtensionsDescription,
        status: l10n.notAvailable,
        detail: l10n.thirdPartyExtensionsDetail,
        enabled: false,
      ),
    ];
    final visible = capabilities
        .where(
          (capability) => '${capability.title} ${capability.description}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = MediaQuery.sizeOf(context).width < 900;
        final horizontal = mobile ? 16.0 : 24.0;
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontal,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!mobile) ...[
                    Text(
                      l10n.plugins,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.pluginsDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search plugins',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 900 + horizontal * 2,
                  child: visible.isEmpty
                      ? Center(
                          child: Text(
                            'No plugins found',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontal,
                            vertical: 24,
                          ),
                          itemCount: visible.length,
                          itemBuilder: (context, index) => visible[index],
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                        ),
                ),
              ),
            ),
          ],
        );
      },
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
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 900;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: mobile ? 48 : 56,
              height: mobile ? 48 : 56,
              decoration: BoxDecoration(
                color: enabled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: mobile ? 24 : 32,
                color: enabled
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(width: mobile ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        (mobile
                                ? Theme.of(context).textTheme.titleMedium
                                : Theme.of(context).textTheme.titleLarge)
                            ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.power_settings_new,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
