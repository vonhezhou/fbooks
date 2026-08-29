import 'package:fbooks/app/providers.dart';
import 'package:fbooks/app/logging/app_logging.dart';
import 'package:fbooks/domain/settings/app_settings.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final books =
        ref.watch(libraryPublicationsProvider).asData?.value.length ?? 0;
    final collections =
        ref.watch(bookCollectionsProvider).asData?.value.length ?? 0;
    final logDirectory = ref.watch(appLogDirectoryProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
      children: [
        Text(
          l10n.settings,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 28),
        _SettingsSection(
          title: l10n.appearance.toUpperCase(),
          child: settings.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => ListTile(
              title: Text(l10n.appearance),
              subtitle: Text(l10n.unableToLoad(error.toString())),
            ),
            data: (value) => Column(
              children: [
                _ThemeModeSelector(settings: value),
                const Divider(height: 1),
                _LanguageSelector(settings: value),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: l10n.library.toUpperCase(),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(l10n.localLibrary),
                subtitle: Text(l10n.booksCount(books)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.collections_bookmark_outlined),
                title: Text(l10n.collections),
                subtitle: Text(l10n.collectionsCount(collections)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: l10n.reading.toUpperCase(),
          child: ListTile(
            leading: const Icon(Icons.tune_outlined),
            title: Text(l10n.comicReadingMode),
            subtitle: Text(l10n.comicReadingModeDescription),
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: 'DIAGNOSTICS',
          child: Column(
            children: [
              _LogLevelSelector(settings: settings.asData?.value),
              const Divider(height: 1),
              _LogDirectoryTile(directory: logDirectory),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: l10n.about.toUpperCase(),
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.appTitle),
            subtitle: Text(l10n.appDescription),
            trailing: const Text('1.0.0'),
          ),
        ),
      ],
    );
  }
}

class _LogLevelSelector extends ConsumerWidget {
  const _LogLevelSelector({required this.settings});

  final AppSettings? settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = settings?.logLevel ?? AppLogLevel.info;
    return ListTile(
      leading: const Icon(Icons.tune_outlined),
      title: const Text('Log level'),
      subtitle: const Text(
        'Choose how much local diagnostic detail to retain.',
      ),
      trailing: DropdownButton<AppLogLevel>(
        value: current,
        onChanged: settings == null
            ? null
            : (next) async {
                if (next == null) {
                  return;
                }
                final updated = settings!.copyWith(logLevel: next);
                await ref.read(appSettingsRepositoryProvider).save(updated);
                applyAppLogLevel(next);
                ref.invalidate(appSettingsProvider);
              },
        items: const [
          DropdownMenuItem(value: AppLogLevel.debug, child: Text('Debug')),
          DropdownMenuItem(value: AppLogLevel.info, child: Text('Info')),
          DropdownMenuItem(value: AppLogLevel.warning, child: Text('Warning')),
          DropdownMenuItem(
            value: AppLogLevel.error,
            child: Text('Errors only'),
          ),
        ],
      ),
    );
  }
}

class _LogDirectoryTile extends StatelessWidget {
  const _LogDirectoryTile({required this.directory});

  final String? directory;

  @override
  Widget build(BuildContext context) {
    final available = directory != null;
    return ListTile(
      enabled: available,
      leading: const Icon(Icons.article_outlined),
      title: const Text('Log directory'),
      subtitle: Text(
        available
            ? 'Tap to copy the path for local diagnostics.'
            : 'Local diagnostics are unavailable for this session.',
      ),
      trailing: available ? const Icon(Icons.content_copy_outlined) : null,
      onTap: !available
          ? null
          : () async {
              await Clipboard.setData(ClipboardData(text: directory!));
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log directory copied.')),
              );
            },
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
          AppLocalizations.of(context).colorMode,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(AppLocalizations.of(context).colorModeDescription),
        const SizedBox(height: 16),
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text(AppLocalizations.of(context).system),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text(AppLocalizations.of(context).light),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text(AppLocalizations.of(context).dark),
            ),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (modes) async {
            final next = modes.single;
            await ref
                .read(appSettingsRepositoryProvider)
                .save(settings.copyWith(themeMode: next));
            ref.invalidate(appSettingsProvider);
          },
        ),
      ],
    ),
  );
}

class _LanguageSelector extends ConsumerWidget {
  const _LanguageSelector({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = switch (settings.locale?.languageCode) {
      'en' => 'en',
      'zh' => 'zh',
      _ => 'system',
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.language,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(l10n.languageDescription),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'system',
                icon: const Icon(Icons.language_outlined),
                label: Text(l10n.languageSystem),
              ),
              ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
              ButtonSegment(
                value: 'zh',
                label: Text(l10n.languageChineseSimplified),
              ),
            ],
            selected: {selected},
            onSelectionChanged: (codes) async {
              final code = codes.single;
              await ref
                  .read(appSettingsRepositoryProvider)
                  .save(
                    settings.copyWith(
                      locale: code == 'system' ? null : Locale(code),
                      clearLocale: code == 'system',
                    ),
                  );
              ref.invalidate(appSettingsProvider);
            },
          ),
        ],
      ),
    );
  }
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
