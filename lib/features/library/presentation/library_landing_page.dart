import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/opds/opds_credentials.dart';
import 'package:fbooks/domain/collection/book_collection.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/features/collections/presentation/collections_page.dart';
import 'package:fbooks/features/library/presentation/publication_details_page.dart';
import 'package:fbooks/features/opds/presentation/opds_catalog_page.dart';
import 'package:fbooks/features/plugins/presentation/plugins_page.dart';
import 'package:fbooks/features/reader/presentation/comic_reader_page.dart';
import 'package:fbooks/features/reader/presentation/pdf_reader_page.dart';
import 'package:fbooks/features/reader/presentation/flow_reader_page.dart';
import 'package:fbooks/features/settings/presentation/settings_page.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
enum _AppSection { library, collections, plugins, settings }

enum _LibrarySourceFilter { all, local, opds }

enum _LibraryFormatFilter { all, comic, epub, text }

enum _LibrarySort { titleAscending, titleDescending }

class LibraryLandingPage extends ConsumerStatefulWidget {
  const LibraryLandingPage({super.key});

  @override
  ConsumerState<LibraryLandingPage> createState() => _LibraryLandingPageState();
}

class _LibraryLandingPageState extends ConsumerState<LibraryLandingPage> {
  bool _isImporting = false;
  var _section = _AppSection.library;
  var _query = '';
  var _sourceFilter = _LibrarySourceFilter.all;
  var _formatFilter = _LibraryFormatFilter.all;
  var _sort = _LibrarySort.titleAscending;
  var _collectionsExpanded = true;
  BookCollection? _selectedDesktopCollection;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final publications = ref.watch(libraryPublicationsProvider);
    final libraryBody = publications.when(
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyLibraryView();
        }
        return _LibraryContent(
          publications: _filterPublications(items),
          query: _query,
          sourceFilter: _sourceFilter,
          formatFilter: _formatFilter,
          sort: _sort,
          onQueryChanged: (value) => setState(() => _query = value),
          onSourceFilterChanged: (value) =>
              setState(() => _sourceFilter = value),
          onFormatFilterChanged: (value) =>
              setState(() => _formatFilter = value),
          onSortChanged: (value) => setState(() => _sort = value),
        );
      },
      error: (error, stackTrace) => Center(
        child: Text(
          AppLocalizations.of(context).unableToLoadLibrary(error.toString()),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
    final body = switch (_section) {
      _AppSection.library => libraryBody,
      _AppSection.collections => const CollectionsPage(),
      _AppSection.plugins => const PluginsPage(),
      _AppSection.settings => const SettingsPage(),
    };
    final desktopBody = switch (_section) {
      _AppSection.collections when _selectedDesktopCollection != null =>
        BookCollectionDetailContent(
          key: const Key('desktop-collection-detail'),
          collection: _selectedDesktopCollection!,
          showAppBar: false,
          desktopLayout: true,
        ),
      _ => body,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_sectionLabel(context)),
              actions: _section == _AppSection.library
                  ? _compactActions(context)
                  : [],
            ),
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _section.index,
              onDestinationSelected: (index) =>
                  setState(() => _section = _AppSection.values[index]),
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.library_books_outlined),
                  label: AppLocalizations.of(context).library,
                ),
                NavigationDestination(
                  icon: Icon(Icons.collections_bookmark_outlined),
                  label: AppLocalizations.of(context).collections,
                ),
                NavigationDestination(
                  icon: Icon(Icons.extension_outlined),
                  label: AppLocalizations.of(context).plugins,
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: AppLocalizations.of(context).settings,
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              _DesktopSidebar(
                section: _section,
                onSelected: (section) => setState(() => _section = section),
                collectionsExpanded: _collectionsExpanded,
                selectedCollection: _selectedDesktopCollection,
                onCollectionsExpandedChanged: (expanded) =>
                    setState(() => _collectionsExpanded = expanded),
                onCollectionsOverviewSelected: () => setState(() {
                  _section = _AppSection.collections;
                  _selectedDesktopCollection = null;
                }),
                onCollectionSelected: (collection) => setState(() {
                  _section = _AppSection.collections;
                  _collectionsExpanded = true;
                  _selectedDesktopCollection = collection;
                }),
              ),
              Expanded(
                child: Material(
                  key: const Key('primary-content-surface'),
                  color: colorScheme.surface,
                  child: Column(
                    children: [
                      if (_section == _AppSection.library)
                        _DesktopHeader(
                          isImporting: _isImporting,
                          onImport: _importLocalPublications,
                          onConnectOpds: _connectOpdsCatalog,
                          onBrowseOpds: _showOpdsCatalogs,
                        ),
                      Expanded(child: desktopBody),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Publication> _filterPublications(List<Publication> publications) {
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = publications.where((publication) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          publication.title.toLowerCase().contains(normalizedQuery) ||
          publication.authors.any(
            (author) => author.toLowerCase().contains(normalizedQuery),
          );
      final matchesSource = switch (_sourceFilter) {
        _LibrarySourceFilter.all => true,
        _LibrarySourceFilter.local =>
          publication.source.kind == LibrarySourceKind.local,
        _LibrarySourceFilter.opds =>
          publication.source.kind == LibrarySourceKind.opds,
      };
      final matchesFormat = switch (_formatFilter) {
        _LibraryFormatFilter.all => true,
        _LibraryFormatFilter.comic =>
          publication.format == PublicationFormat.comicArchive ||
              publication.format == PublicationFormat.comicDirectory,
        _LibraryFormatFilter.epub =>
          publication.format == PublicationFormat.epub,
        _LibraryFormatFilter.text =>
          publication.format == PublicationFormat.text,
      };
      return matchesQuery && matchesSource && matchesFormat;
    }).toList();
    filtered.sort(
      (left, right) => _sort == _LibrarySort.titleAscending
          ? left.title.toLowerCase().compareTo(right.title.toLowerCase())
          : right.title.toLowerCase().compareTo(left.title.toLowerCase()),
    );
    return filtered;
  }

  List<Widget> _compactActions(BuildContext context) => [
    IconButton(
      tooltip: AppLocalizations.of(context).addLocalPublications,
      onPressed: _isImporting ? null : _importLocalPublications,
      icon: _isImporting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_circle_outline),
    ),
    IconButton(
      tooltip: AppLocalizations.of(context).connectOpdsCatalog,
      onPressed: _connectOpdsCatalog,
      icon: const Icon(Icons.add_to_queue_outlined),
    ),
    IconButton(
      tooltip: AppLocalizations.of(context).browseOpdsCatalogs,
      onPressed: _showOpdsCatalogs,
      icon: const Icon(Icons.cloud_outlined),
    ),
  ];

  String _sectionLabel(BuildContext context) => switch (_section) {
    _AppSection.library => AppLocalizations.of(context).appTitle,
    _AppSection.collections => AppLocalizations.of(context).collections,
    _AppSection.plugins => AppLocalizations.of(context).plugins,
    _AppSection.settings => AppLocalizations.of(context).settings,
  };

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
            AppLocalizations.of(context).importSummary(
              result.imported.length,
              result.duplicates.length,
              result.unsupported.length,
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .unableToAddPublications(error.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _connectOpdsCatalog() async {
    final endpointController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final connect = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).connectOpdsCatalog),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: endpointController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'https://example.com/opds',
                  labelText: AppLocalizations.of(context).catalogUrl,
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).usernameOptional,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).passwordOptional,
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).connect),
          ),
        ],
      ),
    );
    final endpointText = endpointController.text;
    final username = usernameController.text.trim();
    final password = passwordController.text;
    endpointController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    if (connect != true || !mounted) {
      return;
    }

    final endpoint = Uri.tryParse(endpointText.trim());
    if (endpoint == null ||
        !endpoint.hasAuthority ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).validHttpCatalogUrlRequired,
          ),
        ),
      );
      return;
    }

    if (username.isNotEmpty != password.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).usernameAndPasswordRequired,
          ),
        ),
      );
      return;
    }
    final source = LibrarySource(
      id: 'opds:$endpoint',
      kind: LibrarySourceKind.opds,
      name: endpoint.host,
      endpoint: endpoint,
    );
    await ref.read(librarySourceRepositoryProvider).save(source);
    if (username.isNotEmpty) {
      await ref
          .read(opdsCredentialsRepositoryProvider)
          .save(
            source.id,
            OpdsCredentials(username: username, password: password),
          );
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OpdsCatalogPage(source: source),
      ),
    );
  }

  Future<void> _showOpdsCatalogs() async {
    final sources = await ref
        .read(librarySourceRepositoryProvider)
        .listSources();
    final opdsSources = sources
        .where((source) => source.kind == LibrarySourceKind.opds)
        .toList();
    if (!mounted) {
      return;
    }
    if (opdsSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).noOpdsCatalogs)),
      );
      return;
    }

    final selectedSource = await showModalBottomSheet<LibrarySource>(
      context: context,
      builder: (context) => ListView(
        children: [
          ListTile(title: Text(AppLocalizations.of(context).opdsCatalogs)),
          for (final source in opdsSources)
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(source.name),
              subtitle: Text(source.endpoint.toString()),
              onTap: () => Navigator.of(context).pop(source),
            ),
        ],
      ),
    );
    if (selectedSource == null || !mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OpdsCatalogPage(source: selectedSource),
      ),
    );
  }
}

class _DesktopSidebar extends ConsumerWidget {
  const _DesktopSidebar({
    required this.section,
    required this.onSelected,
    required this.collectionsExpanded,
    required this.selectedCollection,
    required this.onCollectionsExpandedChanged,
    required this.onCollectionsOverviewSelected,
    required this.onCollectionSelected,
  });

  final _AppSection section;
  final ValueChanged<_AppSection> onSelected;
  final bool collectionsExpanded;
  final BookCollection? selectedCollection;
  final ValueChanged<bool> onCollectionsExpandedChanged;
  final VoidCallback onCollectionsOverviewSelected;
  final ValueChanged<BookCollection> onCollectionSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customCollections =
        ref.watch(bookCollectionsProvider).asData?.value ??
        const <BookCollection>[];
    final collections = [...SystemBookCollections.all, ...customCollections];
    return Container(
      width: 248,
      color: const Color(0xFF1C1D20),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Image(
                    key: Key('brand-logo'),
                    image: AssetImage('launcher_icon/fbooks_icon.png'),
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context).appTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _SidebarItem(
                      icon: Icons.library_books_outlined,
                      label: AppLocalizations.of(context).library,
                      selected: section == _AppSection.library,
                      onTap: () => onSelected(_AppSection.library),
                    ),
                    _CollectionsSidebarGroup(
                      collections: collections,
                      expanded: collectionsExpanded,
                      selectedCollection: selectedCollection,
                      selected: section == _AppSection.collections,
                      onExpandedChanged: onCollectionsExpandedChanged,
                      onOverviewSelected: onCollectionsOverviewSelected,
                      onCollectionSelected: onCollectionSelected,
                    ),
                  ],
                ),
              ),
              _SidebarItem(
                icon: Icons.extension_outlined,
                label: AppLocalizations.of(context).plugins,
                selected: section == _AppSection.plugins,
                onTap: () => onSelected(_AppSection.plugins),
              ),
              _SidebarItem(
                icon: Icons.settings_outlined,
                label: AppLocalizations.of(context).settings,
                selected: section == _AppSection.settings,
                onTap: () => onSelected(_AppSection.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionsSidebarGroup extends StatelessWidget {
  const _CollectionsSidebarGroup({
    required this.collections,
    required this.expanded,
    required this.selectedCollection,
    required this.selected,
    required this.onExpandedChanged,
    required this.onOverviewSelected,
    required this.onCollectionSelected,
  });

  final List<BookCollection> collections;
  final bool expanded;
  final BookCollection? selectedCollection;
  final bool selected;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onOverviewSelected;
  final ValueChanged<BookCollection> onCollectionSelected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _SidebarItem(
        icon: Icons.collections_bookmark_outlined,
        label: AppLocalizations.of(context).collections,
        selected: selected && selectedCollection == null,
        onTap: onOverviewSelected,
        trailing: IconButton(
          tooltip: expanded
              ? AppLocalizations.of(context).collapseCollections
              : AppLocalizations.of(context).expandCollections,
          onPressed: () => onExpandedChanged(!expanded),
          color: Colors.white70,
          icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
        ),
      ),
      if (expanded)
        for (final collection in collections)
          _CollectionSidebarItem(
            collection: collection,
            selected: selectedCollection?.id == collection.id,
            onTap: () => onCollectionSelected(collection),
          ),
    ],
  );
}

class _CollectionSidebarItem extends ConsumerWidget {
  const _CollectionSidebarItem({
    required this.collection,
    required this.selected,
    required this.onTap,
  });

  final BookCollection collection;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(collectionPublicationIdsProvider(collection.id))
        .asData
        ?.value
        .length;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: _SidebarItem(
        key: Key('sidebar-collection-${collection.id}'),
        icon: _collectionIcon(collection.id),
        label: collection.name,
        selected: selected,
        onTap: onTap,
        trailing: count == null
            ? const SizedBox(width: 24, height: 24)
            : Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white70 : Colors.white54,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
      ),
    );
  }
}

IconData _collectionIcon(String id) => switch (id) {
  SystemBookCollections.readingList => Icons.schedule_outlined,
  SystemBookCollections.favorites => Icons.favorite_border,
  _ => Icons.bookmark_outline,
};

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF35373C) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? const Color(0xFFD8FF67) : Colors.white60,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({
    required this.isImporting,
    required this.onImport,
    required this.onConnectOpds,
    required this.onBrowseOpds,
  });

  final bool isImporting;
  final VoidCallback onImport;
  final VoidCallback onConnectOpds;
  final VoidCallback onBrowseOpds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 28, 36, 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppLocalizations.of(context).yourLibrary,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).browseOpdsCatalogs,
            onPressed: onBrowseOpds,
            icon: const Icon(Icons.cloud_outlined),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onConnectOpds,
            icon: const Icon(Icons.add_to_queue_outlined),
            label: Text(AppLocalizations.of(context).connectOpds),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: isImporting ? null : onImport,
            icon: isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(AppLocalizations.of(context).addBooks),
          ),
        ],
      ),
    );
  }
}

class _EmptyLibraryView extends StatelessWidget {
  const _EmptyLibraryView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 64),
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).libraryWelcome,
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).libraryWelcomeDescription,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent({
    required this.publications,
    required this.query,
    required this.sourceFilter,
    required this.formatFilter,
    required this.sort,
    required this.onQueryChanged,
    required this.onSourceFilterChanged,
    required this.onFormatFilterChanged,
    required this.onSortChanged,
  });

  final List<Publication> publications;
  final String query;
  final _LibrarySourceFilter sourceFilter;
  final _LibraryFormatFilter formatFilter;
  final _LibrarySort sort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_LibrarySourceFilter> onSourceFilterChanged;
  final ValueChanged<_LibraryFormatFilter> onFormatFilterChanged;
  final ValueChanged<_LibrarySort> onSortChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _LibraryFilterBar(
        query: query,
        sourceFilter: sourceFilter,
        formatFilter: formatFilter,
        sort: sort,
        onQueryChanged: onQueryChanged,
        onSourceFilterChanged: onSourceFilterChanged,
        onFormatFilterChanged: onFormatFilterChanged,
        onSortChanged: onSortChanged,
      ),
      Expanded(
        child: publications.isEmpty
            ? const _NoSearchResults()
            : _PublicationList(publications: publications),
      ),
    ],
  );
}

class _LibraryFilterBar extends StatelessWidget {
  const _LibraryFilterBar({
    required this.query,
    required this.sourceFilter,
    required this.formatFilter,
    required this.sort,
    required this.onQueryChanged,
    required this.onSourceFilterChanged,
    required this.onFormatFilterChanged,
    required this.onSortChanged,
  });

  final String query;
  final _LibrarySourceFilter sourceFilter;
  final _LibraryFormatFilter formatFilter;
  final _LibrarySort sort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_LibrarySourceFilter> onSourceFilterChanged;
  final ValueChanged<_LibraryFormatFilter> onFormatFilterChanged;
  final ValueChanged<_LibrarySort> onSortChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final search = TextFormField(
          initialValue: query,
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).searchLibrary,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: AppLocalizations.of(context).clearSearch,
                    onPressed: () => onQueryChanged(''),
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        );
        final controls = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterMenu<_LibrarySourceFilter>(
              tooltip: AppLocalizations.of(context).filterSource,
              value: sourceFilter,
              items: {
                _LibrarySourceFilter.all: AppLocalizations.of(context)
                    .allSources,
                _LibrarySourceFilter.local: AppLocalizations.of(context)
                    .localSource,
                _LibrarySourceFilter.opds: AppLocalizations.of(context)
                    .opdsSource,
              },
              onChanged: onSourceFilterChanged,
            ),
            _FilterMenu<_LibraryFormatFilter>(
              tooltip: AppLocalizations.of(context).filterFormat,
              value: formatFilter,
              items: {
                _LibraryFormatFilter.all: AppLocalizations.of(context)
                    .allFormats,
                _LibraryFormatFilter.comic: AppLocalizations.of(context)
                    .comicFormat,
                _LibraryFormatFilter.epub: AppLocalizations.of(context)
                    .epubFormat,
                _LibraryFormatFilter.text: AppLocalizations.of(context)
                    .textFormat,
              },
              onChanged: onFormatFilterChanged,
            ),
            _FilterMenu<_LibrarySort>(
              tooltip: AppLocalizations.of(context).sortPublications,
              value: sort,
              items: {
                _LibrarySort.titleAscending: AppLocalizations.of(context)
                    .sortByTitleAscending,
                _LibrarySort.titleDescending: AppLocalizations.of(context)
                    .sortByTitleDescending,
              },
              onChanged: onSortChanged,
            ),
          ],
        );
        return constraints.maxWidth < 620
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [search, const SizedBox(height: 8), controls],
              )
            : Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 12),
                  controls,
                ],
              );
      },
    ),
  );
}

class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.tooltip,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String tooltip;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        borderRadius: BorderRadius.circular(12),
        items: items.entries
            .map(
              (entry) => DropdownMenuItem<T>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(growable: false),
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    ),
  );
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_outlined, size: 48),
          SizedBox(height: 12),
          Text(AppLocalizations.of(context).noMatchingPublications),
          SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).noMatchingPublicationsDescription,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _PublicationList extends ConsumerWidget {
  const _PublicationList({required this.publications});

  final List<Publication> publications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(36, 8, 36, 36),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisExtent: 304,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
            ),
            itemCount: publications.length,
            itemBuilder: (context, index) => _PublicationCard(
              publication: publications[index],
              progress: ref
                  .watch(readingProgressProvider(publications[index].id))
                  .asData
                  ?.value,
              onTap: () => _openPublication(context, ref, publications[index]),
              onDetails: () =>
                  _showPublicationDetails(context, publications[index]),
              icon: _iconFor(publications[index].format),
              formatLabel: _formatLabel(publications[index].format),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: publications.length,
          itemBuilder: (context, index) {
            final publication = publications[index];
            final progress = ref.watch(readingProgressProvider(publication.id));
            return ListTile(
              leading: Icon(_iconFor(publication.format)),
              title: Text(publication.title),
              subtitle: _PublicationSubtitle(
                publication: publication,
                progress: progress.asData?.value,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatLabel(publication.format)),
                  IconButton(
                    tooltip: 'Publication details',
                    onPressed: () =>
                        _showPublicationDetails(context, publication),
                    icon: const Icon(Icons.info_outline),
                  ),
                ],
              ),
              onTap: () => _openPublication(context, ref, publication),
            );
          },
          separatorBuilder: (context, index) => const Divider(height: 1),
        );
      },
    );
  }

  void _openPublication(
    BuildContext context,
    WidgetRef ref,
    Publication publication,
  ) {
    switch (publication.format) {
      case PublicationFormat.comicArchive:
        _openReader(
          context,
          ref,
          publication.id,
          MaterialPageRoute<void>(
            builder: (context) => ComicReaderPage(
              publicationId: publication.id,
              title: publication.title,
            ),
          ),
        );
        return;
      case PublicationFormat.epub || PublicationFormat.text:
        _openReader(
          context,
          ref,
          publication.id,
          MaterialPageRoute<void>(
            builder: (context) => FlowReaderPage(
              publicationId: publication.id,
              title: publication.title,
            ),
          ),
        );
        return;
      case PublicationFormat.pdf:
        _openReader(
          context,
          ref,
          publication.id,
          MaterialPageRoute<void>(
            builder: (context) => PdfReaderPage(
              publicationId: publication.id,
              title: publication.title,
            ),
          ),
        );
        return;
      default:
        return;
    }
  }

  Future<void> _openReader(
    BuildContext context,
    WidgetRef ref,
    PublicationId publicationId,
    Route<void> route,
  ) async {
    await Navigator.of(context).push(route);
    ref.invalidate(readingProgressProvider(publicationId));
  }

  void _showPublicationDetails(BuildContext context, Publication publication) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PublicationDetailsPage(publication: publication),
      ),
    );
  }

  IconData _iconFor(PublicationFormat format) {
    return switch (format) {
      PublicationFormat.comicArchive ||
      PublicationFormat.comicDirectory => Icons.auto_stories_outlined,
      PublicationFormat.epub ||
      PublicationFormat.text => Icons.menu_book_outlined,
      PublicationFormat.pdf => Icons.picture_as_pdf_outlined,
    };
  }

  String _formatLabel(PublicationFormat format) {
    return switch (format) {
      PublicationFormat.comicArchive => 'CBZ',
      PublicationFormat.comicDirectory => 'Comic',
      PublicationFormat.epub => 'EPUB',
      PublicationFormat.pdf => 'PDF',
      PublicationFormat.text => 'TXT',
    };
  }
}

class _PublicationCard extends StatelessWidget {
  const _PublicationCard({
    required this.publication,
    required this.progress,
    required this.onTap,
    required this.onDetails,
    required this.icon,
    required this.formatLabel,
  });

  final Publication publication;
  final ReadingProgress? progress;
  final VoidCallback onTap;
  final VoidCallback onDetails;
  final IconData icon;
  final String formatLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _coverColor(publication.format),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(icon, size: 52, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    publication.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress == null ? formatLabel : _resumeLabel(progress!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: 'Publication details',
              onPressed: onDetails,
              icon: const Icon(Icons.info_outline),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: .88),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _coverColor(PublicationFormat format) => switch (format) {
    PublicationFormat.comicArchive ||
    PublicationFormat.comicDirectory => const Color(0xFF455A64),
    PublicationFormat.epub => const Color(0xFF6D597A),
    PublicationFormat.text => const Color(0xFF5B7C6F),
    PublicationFormat.pdf => const Color(0xFF9B3D3D),
  };

  String _resumeLabel(ReadingProgress progress) => switch (progress.locator) {
    ComicPageLocator(:final pageIndex) => 'Page ${pageIndex + 1}',
    PdfPageLocator(:final pageNumber) => 'Page $pageNumber',
    TextOffsetLocator(:final chapterIndex) => 'Chapter ${chapterIndex + 1}',
    EpubCfiLocator() => 'Resume reading',
  };
}

class _PublicationSubtitle extends StatelessWidget {
  const _PublicationSubtitle({
    required this.publication,
    required this.progress,
  });

  final Publication publication;
  final ReadingProgress? progress;

  @override
  Widget build(BuildContext context) {
    final attribution = publication.authors.isEmpty
        ? publication.source.name
        : publication.authors.join(', ');
    final resumeLabel = switch (progress?.locator) {
      ComicPageLocator(:final pageIndex) => 'Resume at page ${pageIndex + 1}',
      PdfPageLocator(:final pageNumber) => 'Resume at page $pageNumber',
      TextOffsetLocator(:final chapterIndex) =>
        'Resume at chapter ${chapterIndex + 1}',
      EpubCfiLocator() => 'Resume reading',
      null => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(attribution),
        if (resumeLabel != null)
          Text(
            resumeLabel,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
      ],
    );
  }
}
