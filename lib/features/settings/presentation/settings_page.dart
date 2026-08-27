import 'package:fbooks/app/providers.dart';
import 'package:fbooks/domain/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final books =
        ref.watch(libraryPublicationsProvider).asData?.value.length ?? 0;
    final collections =
        ref.watch(bookCollectionsProvider).asData?.value.length ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 28),
        _SettingsSection(
          title: 'APPEARANCE',
          child: settings.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => ListTile(
              title: const Text('Appearance'),
              subtitle: Text('Unable to load: $error'),
            ),
            data: (value) => _ThemeModeSelector(settings: value),
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: 'LIBRARY',
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Local library'),
                subtitle: Text('$books imported books'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.collections_bookmark_outlined),
                title: const Text('Collections'),
                subtitle: Text('$collections custom collections'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: 'READING',
          child: const ListTile(
            leading: Icon(Icons.tune_outlined),
            title: Text('Comic reading mode'),
            subtitle: Text(
              'Choose direction and page spread from the comic reader toolbar.',
            ),
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: 'ABOUT',
          child: const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Fbooks'),
            subtitle: Text('A local-first reader for comics and ebooks.'),
            trailing: Text('1.0.0'),
          ),
        ),
      ],
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color mode',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Follow the system or choose a permanent reading environment.',
        ),
        const SizedBox(height: 16),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text('System'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Light'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Dark'),
            ),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (modes) async {
            final next = modes.single;
            await ref
                .read(appSettingsRepositoryProvider)
                .save(AppSettings(themeMode: next));
            ref.invalidate(appSettingsProvider);
          },
        ),
      ],
    ),
  );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
      const SizedBox(height: 8),
      Card(child: child),
    ],
  );
}
