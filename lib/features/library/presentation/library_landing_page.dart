import 'package:fbooks/app/providers.dart';
import 'package:fbooks/app/window/window_caption.dart';
import 'package:fbooks/application/opds/opds_credentials.dart';
import 'package:fbooks/domain/collection/book_collection.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/features/collections/presentation/collections_page.dart';
import 'package:fbooks/features/collections/presentation/collection_membership_manager.dart';
import 'package:fbooks/features/library/presentation/publication_details_page.dart';
import 'package:fbooks/features/library/presentation/publication_card_grid_delegate.dart';
import 'package:fbooks/features/library/presentation/publication_cover.dart';
import 'package:fbooks/features/opds/presentation/opds_catalog_page.dart';
import 'package:fbooks/features/plugins/presentation/plugins_page.dart';
import 'package:fbooks/features/reader/presentation/comic_reader_page.dart';
import 'package:fbooks/features/reader/presentation/pdf_reader_page.dart';
import 'package:fbooks/features/reader/presentation/flow_reader_page.dart';
import 'package:fbooks/features/settings/presentation/settings_page.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:fbooks/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _AppSection { library, collections, plugins, settings }

enum _LibrarySourceFilter { all, local, opds }

enum _LibraryFormatFilter { all, comic, epub, text }

enum _LibrarySort { title, author, lastRead, added }

enum _LibraryViewMode { cards, list }

const _libraryCoverAspectRatio = 1 / 1.6;
const _publicationCardFooterExtent = 84.0;

enum _PublicationAction {
  open,
  details,
  favorite,
  readLater,
  finished,
  collection,
  repair,
  delete,
}

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
  var _sort = _LibrarySort.title;
  var _sortDescending = false;
  var _viewMode = _LibraryViewMode.cards;
  var _selectionMode = false;
  final _selectedPublicationIds = <PublicationId>{};
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
          sortDescending: _sortDescending,
          onSortDescendingChanged: (value) =>
              setState(() => _sortDescending = value),
          viewMode: _viewMode,
          onViewModeChanged: (value) => setState(() => _viewMode = value),
          selectionMode: _selectionMode,
          selectedPublicationIds: _selectedPublicationIds,
          onSelectionModeChanged: (enabled) => setState(() {
            _selectionMode = enabled;
            if (!enabled) {
              _selectedPublicationIds.clear();
            }
          }),
          onSelectionChanged: (id) => setState(() {
            if (!_selectedPublicationIds.add(id)) {
              _selectedPublicationIds.remove(id);
            }
          }),
          onSelectionStarted: (id) => setState(() {
            if (!_selectionMode) {
              _selectionMode = true;
              _selectedPublicationIds.clear();
            }
            _selectedPublicationIds.add(id);
          }),
          onSelectAll: () => setState(
            () => _selectedPublicationIds
              ..clear()
              ..addAll(_filterPublications(items).map((item) => item.id)),
          ),
          onManageCollections: () => showCollectionMembershipManager(
            context,
            ref,
            _selectedPublicationIds,
          ),
          onDeleteSelected: _deleteSelected,
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
      _AppSection.library => _DesktopLibraryPage(
        body: libraryBody,
        isImporting: _isImporting,
        onImport: _importLocalPublications,
        onConnectOpds: _connectOpdsCatalog,
        onBrowseOpds: _showOpdsCatalogs,
      ),
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
            appBar: fbooksAppBar(
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
                      const DesktopWindowCaption(),
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

  Future<void> _deleteSelected() async {
    final selected = {..._selectedPublicationIds};
    if (selected.isEmpty) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove selected books?'),
        content: Text(
          '${selected.length} books will be removed from the library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) {
      return;
    }
    final remover = ref.read(libraryPublicationRemoverProvider);
    for (final id in selected) {
      await remover.remove(id, deleteManagedFiles: false);
    }
    if (mounted) {
      setState(() {
        _selectedPublicationIds.clear();
        _selectionMode = false;
      });
    }
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
    int compareText(String left, String right) =>
        left.toLowerCase().compareTo(right.toLowerCase());
    int compareDate(DateTime? left, DateTime? right) {
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return left.compareTo(right);
    }

    filtered.sort((left, right) {
      final result = switch (_sort) {
        _LibrarySort.title => compareText(left.title, right.title),
        _LibrarySort.author => compareText(
          left.authors.isEmpty ? '' : left.authors.first,
          right.authors.isEmpty ? '' : right.authors.first,
        ),
        _LibrarySort.lastRead => compareDate(left.lastReadAt, right.lastReadAt),
        _LibrarySort.added => compareDate(left.addedAt, right.addedAt),
      };
      final ordered = _sortDescending ? -result : result;
      return ordered != 0 ? ordered : compareText(left.title, right.title);
    });
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
    } catch (error) {
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
                    image: Assets.launcherIcon.fbooksIcon.provider(),
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
  SystemBookCollections.readLater => Icons.schedule_outlined,
  SystemBookCollections.favorites => Icons.favorite_border,
  SystemBookCollections.finished => Icons.check_circle_outline,
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
    return Row(
      key: const Key('desktop-library-header'),
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
    );
  }
}

class _DesktopLibraryPage extends StatelessWidget {
  const _DesktopLibraryPage({
    required this.body,
    required this.isImporting,
    required this.onImport,
    required this.onConnectOpds,
    required this.onBrowseOpds,
  });

  final Widget body;
  final bool isImporting;
  final VoidCallback onImport;
  final VoidCallback onConnectOpds;
  final VoidCallback onBrowseOpds;

  @override
  Widget build(BuildContext context) => _DesktopLibraryLayout(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          _DesktopHeader(
            isImporting: isImporting,
            onImport: onImport,
            onConnectOpds: onConnectOpds,
            onBrowseOpds: onBrowseOpds,
          ),
          const SizedBox(height: 20),
          Expanded(child: body),
        ],
      ),
    ),
  );
}

class _DesktopLibraryLayout extends InheritedWidget {
  const _DesktopLibraryLayout({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DesktopLibraryLayout>() !=
      null;

  @override
  bool updateShouldNotify(_DesktopLibraryLayout oldWidget) => false;
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
    required this.sortDescending,
    required this.onSortDescendingChanged,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.selectionMode,
    required this.selectedPublicationIds,
    required this.onSelectionModeChanged,
    required this.onSelectionChanged,
    required this.onSelectionStarted,
    required this.onSelectAll,
    required this.onManageCollections,
    required this.onDeleteSelected,
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
  final bool sortDescending;
  final ValueChanged<bool> onSortDescendingChanged;
  final _LibraryViewMode viewMode;
  final ValueChanged<_LibraryViewMode> onViewModeChanged;
  final bool selectionMode;
  final Set<PublicationId> selectedPublicationIds;
  final ValueChanged<bool> onSelectionModeChanged;
  final ValueChanged<PublicationId> onSelectionChanged;
  final ValueChanged<PublicationId> onSelectionStarted;
  final VoidCallback onSelectAll;
  final VoidCallback onManageCollections;
  final Future<void> Function() onDeleteSelected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (selectionMode)
        _LibrarySelectionBar(
          selectedCount: selectedPublicationIds.length,
          onDone: () => onSelectionModeChanged(false),
          onSelectAll: onSelectAll,
          onManageCollections: onManageCollections,
          onDelete: onDeleteSelected,
        )
      else
        _LibraryFilterBar(
          query: query,
          sourceFilter: sourceFilter,
          formatFilter: formatFilter,
          sort: sort,
          onQueryChanged: onQueryChanged,
          onSourceFilterChanged: onSourceFilterChanged,
          onFormatFilterChanged: onFormatFilterChanged,
          onSortChanged: onSortChanged,
          sortDescending: sortDescending,
          onSortDescendingChanged: onSortDescendingChanged,
          viewMode: viewMode,
          onViewModeChanged: onViewModeChanged,
          onSelectionModeChanged: onSelectionModeChanged,
        ),
      Expanded(
        child: publications.isEmpty
            ? const _NoSearchResults()
            : _PublicationList(
                publications: publications,
                viewMode: viewMode,
                selectionMode: selectionMode,
                selectedPublicationIds: selectedPublicationIds,
                onSelectionChanged: onSelectionChanged,
                onSelectionStarted: onSelectionStarted,
              ),
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
    required this.sortDescending,
    required this.onSortDescendingChanged,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.onSelectionModeChanged,
  });

  final String query;
  final _LibrarySourceFilter sourceFilter;
  final _LibraryFormatFilter formatFilter;
  final _LibrarySort sort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_LibrarySourceFilter> onSourceFilterChanged;
  final ValueChanged<_LibraryFormatFilter> onFormatFilterChanged;
  final ValueChanged<_LibrarySort> onSortChanged;
  final bool sortDescending;
  final ValueChanged<bool> onSortDescendingChanged;
  final _LibraryViewMode viewMode;
  final ValueChanged<_LibraryViewMode> onViewModeChanged;
  final ValueChanged<bool> onSelectionModeChanged;

  @override
  Widget build(BuildContext context) {
    final desktop = _DesktopLibraryLayout.of(context);
    return Padding(
      key: const Key('library-filter-bar'),
      padding: desktop
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: LayoutBuilder(
        key: const Key('library-filter-controls'),
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
              MenuAnchor(
                menuChildren: [
                  SubmenuButton(
                    menuChildren: [
                      for (final value in _LibrarySourceFilter.values)
                        RadioMenuButton(
                          value: value,
                          groupValue: sourceFilter,
                          onChanged: (value) => onSourceFilterChanged(value!),
                          child: Text(value.name),
                        ),
                    ],
                    child: const Text('Source'),
                  ),
                  SubmenuButton(
                    menuChildren: [
                      for (final value in _LibraryFormatFilter.values)
                        RadioMenuButton(
                          value: value,
                          groupValue: formatFilter,
                          onChanged: (value) => onFormatFilterChanged(value!),
                          child: Text(value.name),
                        ),
                    ],
                    child: const Text('Format'),
                  ),
                  const Divider(),
                  SubmenuButton(
                    menuChildren: [
                      for (final value in _LibrarySort.values)
                        RadioMenuButton(
                          value: value,
                          groupValue: sort,
                          onChanged: (value) => onSortChanged(value!),
                          child: Text(value.name),
                        ),
                    ],
                    child: const Text('Sort by'),
                  ),
                  RadioMenuButton(
                    value: false,
                    groupValue: sortDescending,
                    onChanged: (value) => onSortDescendingChanged(value!),
                    child: const Text('Ascending'),
                  ),
                  RadioMenuButton(
                    value: true,
                    groupValue: sortDescending,
                    onChanged: (value) => onSortDescendingChanged(value!),
                    child: const Text('Descending'),
                  ),
                ],
                builder: (context, controller, child) => IconButton(
                  tooltip: 'Filter and sort',
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                  icon: const Icon(Icons.tune),
                ),
              ),
              IconButton(
                tooltip: viewMode == _LibraryViewMode.cards
                    ? 'Show list'
                    : 'Show cards',
                onPressed: () => onViewModeChanged(
                  viewMode == _LibraryViewMode.cards
                      ? _LibraryViewMode.list
                      : _LibraryViewMode.cards,
                ),
                icon: Icon(
                  viewMode == _LibraryViewMode.cards
                      ? Icons.view_list_outlined
                      : Icons.grid_view_outlined,
                ),
              ),
              IconButton(
                tooltip: 'Select books',
                onPressed: () => onSelectionModeChanged(true),
                icon: const Icon(Icons.checklist),
              ),
            ],
          );
          return constraints.maxWidth < 900
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

class _LibrarySelectionBar extends ConsumerWidget {
  const _LibrarySelectionBar({
    required this.selectedCount,
    required this.onDone,
    required this.onSelectAll,
    required this.onManageCollections,
    required this.onDelete,
  });
  final int selectedCount;
  final VoidCallback onDone;
  final VoidCallback onSelectAll;
  final VoidCallback onManageCollections;
  final Future<void> Function() onDelete;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          IconButton(onPressed: onDone, icon: const Icon(Icons.close)),
          Text('$selectedCount selected'),
          const Spacer(),
          TextButton(onPressed: onSelectAll, child: const Text('Select all')),
          IconButton(
            tooltip: 'Manage collections',
            onPressed: selectedCount == 0 ? null : onManageCollections,
            icon: const Icon(Icons.playlist_add),
          ),
          IconButton(
            onPressed: selectedCount == 0 ? null : onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _PublicationList extends ConsumerWidget {
  const _PublicationList({
    required this.publications,
    required this.viewMode,
    required this.selectionMode,
    required this.selectedPublicationIds,
    required this.onSelectionChanged,
    required this.onSelectionStarted,
  });

  final List<Publication> publications;
  final _LibraryViewMode viewMode;
  final bool selectionMode;
  final Set<PublicationId> selectedPublicationIds;
  final ValueChanged<PublicationId> onSelectionChanged;
  final ValueChanged<PublicationId> onSelectionStarted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (viewMode == _LibraryViewMode.cards) {
          final desktop = _DesktopLibraryLayout.of(context);
          return GridView.builder(
            key: const Key('library-publication-grid'),
            padding: desktop
                ? const EdgeInsets.only(top: 20)
                : const EdgeInsets.fromLTRB(36, 8, 36, 36),
            gridDelegate: const PublicationCardGridDelegate(
              maxCrossAxisExtent: 240,
              coverAspectRatio: _libraryCoverAspectRatio,
              footerExtent: _publicationCardFooterExtent,
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
              formatLabel: _formatLabel(publications[index].format),
              selected: selectedPublicationIds.contains(publications[index].id),
              selectionMode: selectionMode,
              onSelected: () => onSelectionChanged(publications[index].id),
              onLongPress: () => onSelectionStarted(publications[index].id),
              onSecondaryTapUp: (details) => _showPublicationActionMenu(
                context: context,
                ref: ref,
                publication: publications[index],
                onOpen: () =>
                    _openPublication(context, ref, publications[index]),
                onDetails: () =>
                    _showPublicationDetails(context, publications[index]),
                position: _menuPosition(context, details.globalPosition),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: publications.length,
          itemBuilder: (context, index) {
            final publication = publications[index];
            final progress = ref.watch(readingProgressProvider(publication.id));
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () => onSelectionStarted(publication.id),
              onSecondaryTapUp: (details) => _showPublicationActionMenu(
                context: context,
                ref: ref,
                publication: publication,
                onOpen: () => _openPublication(context, ref, publication),
                onDetails: () => _showPublicationDetails(context, publication),
                position: _menuPosition(context, details.globalPosition),
              ),
              child: ListTile(
                leading: selectionMode
                    ? Checkbox(
                        value: selectedPublicationIds.contains(publication.id),
                        onChanged: (_) => onSelectionChanged(publication.id),
                      )
                    : SizedBox(
                        width: 36,
                        height: 52,
                        child: PublicationCover(publication: publication),
                      ),
                title: Text(publication.title),
                subtitle: _PublicationSubtitle(
                  publication: publication,
                  progress: progress.asData?.value,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_formatLabel(publication.format)),
                    _PublicationActionsButton(
                      publication: publication,
                      onOpen: () => _openPublication(context, ref, publication),
                      onDetails: () =>
                          _showPublicationDetails(context, publication),
                    ),
                  ],
                ),
                onTap: selectionMode
                    ? () => onSelectionChanged(publication.id)
                    : () => _openPublication(context, ref, publication),
              ),
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
    required this.formatLabel,
    required this.selected,
    required this.selectionMode,
    required this.onSelected,
    required this.onLongPress,
    required this.onSecondaryTapUp,
  });

  final Publication publication;
  final ReadingProgress? progress;
  final VoidCallback onTap;
  final VoidCallback onDetails;
  final String formatLabel;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onSelected;
  final VoidCallback onLongPress;
  final ValueChanged<TapUpDetails> onSecondaryTapUp;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('publication-card-${publication.id}'),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: selectionMode ? onSelected : onTap,
              onLongPress: onLongPress,
              onSecondaryTapUp: onSecondaryTapUp,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: _libraryCoverAspectRatio,
                    child: PublicationCover(
                      key: Key('publication-card-cover-${publication.id}'),
                      publication: publication,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  SizedBox(
                    height: _publicationCardFooterExtent,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            publication.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  progress == null
                                      ? formatLabel
                                      : _resumeLabel(progress!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              SizedBox(
                                key: Key(
                                  'publication-details-${publication.id}',
                                ),
                                width: 40,
                                height: 40,
                                child: _PublicationActionsButton(
                                  publication: publication,
                                  onOpen: onTap,
                                  onDetails: onDetails,
                                  compact: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selectionMode)
            Positioned(
              left: 4,
              top: 4,
              child: IgnorePointer(
                child: Checkbox(value: selected, onChanged: null),
              ),
            ),
        ],
      ),
    );
  }

  String _resumeLabel(ReadingProgress progress) => switch (progress.locator) {
    ComicPageLocator(:final pageIndex) => 'Page ${pageIndex + 1}',
    PdfPageLocator(:final pageNumber) => 'Page $pageNumber',
    TextOffsetLocator(:final chapterIndex) => 'Chapter ${chapterIndex + 1}',
    EpubCfiLocator() => 'Resume reading',
  };
}

class _PublicationActionsButton extends ConsumerWidget {
  const _PublicationActionsButton({
    required this.publication,
    required this.onOpen,
    required this.onDetails,
    this.compact = false,
  });

  final Publication publication;
  final VoidCallback onOpen;
  final VoidCallback onDetails;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      PopupMenuButton<_PublicationAction>(
        tooltip: 'Book actions',
        icon: const Icon(Icons.more_vert),
        iconSize: compact ? 18 : null,
        style: compact
            ? IconButton.styleFrom(
                padding: EdgeInsets.zero,
                fixedSize: const Size.square(40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
            : null,
        onSelected: (action) async {
          await _handlePublicationAction(
            context: context,
            ref: ref,
            publication: publication,
            onOpen: onOpen,
            onDetails: onDetails,
            action: action,
          );
        },
        itemBuilder: (context) => _publicationActionMenuItems(publication),
      );
}

RelativeRect _menuPosition(BuildContext context, Offset globalPosition) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  return RelativeRect.fromRect(
    Rect.fromCircle(center: globalPosition, radius: 1),
    Offset.zero & overlay.size,
  );
}

Future<void> _showPublicationActionMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Publication publication,
  required VoidCallback onOpen,
  required VoidCallback onDetails,
  required RelativeRect position,
}) async {
  final action = await showMenu<_PublicationAction>(
    context: context,
    position: position,
    items: _publicationActionMenuItems(publication),
  );
  if (action == null || !context.mounted) {
    return;
  }
  await _handlePublicationAction(
    context: context,
    ref: ref,
    publication: publication,
    onOpen: onOpen,
    onDetails: onDetails,
    action: action,
  );
}

Future<void> _handlePublicationAction({
  required BuildContext context,
  required WidgetRef ref,
  required Publication publication,
  required VoidCallback onOpen,
  required VoidCallback onDetails,
  required _PublicationAction action,
}) async {
  if (action == _PublicationAction.open) {
    onOpen();
    return;
  }
  if (action == _PublicationAction.details) {
    onDetails();
    return;
  }
  if (action == _PublicationAction.collection) {
    await showCollectionMembershipManager(context, ref, {publication.id});
    return;
  }
  if (action == _PublicationAction.repair) {
    await repairLocalPublication(
      context,
      ref,
      publication,
      closePageOnSuccess: false,
    );
    return;
  }
  if (action == _PublicationAction.delete) {
    await confirmPublicationRemoval(
      context,
      ref,
      publication,
      closePageOnSuccess: false,
    );
    return;
  }
  final collectionId = switch (action) {
    _PublicationAction.favorite => SystemBookCollections.favorites,
    _PublicationAction.readLater => SystemBookCollections.readLater,
    _PublicationAction.finished => SystemBookCollections.finished,
    _PublicationAction.collection ||
    _PublicationAction.repair ||
    _PublicationAction.delete => throw StateError('Handled above.'),
    _PublicationAction.open => throw StateError('Handled above.'),
    _PublicationAction.details => throw StateError('Handled above.'),
  };
  final repository = ref.read(bookCollectionRepositoryProvider);
  final ids = await repository.listPublicationIds(collectionId);
  if (ids.contains(publication.id)) {
    await repository.removePublication(collectionId, publication.id);
  } else {
    await repository.addPublication(collectionId, publication.id);
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Added “${publication.title}”.')));
  }
}

List<PopupMenuEntry<_PublicationAction>> _publicationActionMenuItems(
  Publication publication,
) => [
  PopupMenuItem(
    value: _PublicationAction.open,
    child: ListTile(
      leading: Icon(Icons.menu_book_outlined),
      title: Text('Open / continue reading'),
    ),
  ),
  PopupMenuItem(
    value: _PublicationAction.details,
    child: ListTile(leading: Icon(Icons.info_outline), title: Text('Details')),
  ),
  PopupMenuDivider(),
  PopupMenuItem(
    value: _PublicationAction.favorite,
    child: ListTile(
      leading: Icon(Icons.favorite_border),
      title: Text('Toggle favorite'),
    ),
  ),
  PopupMenuItem(
    value: _PublicationAction.readLater,
    child: ListTile(
      leading: Icon(Icons.schedule_outlined),
      title: Text('Toggle Read later'),
    ),
  ),
  PopupMenuItem(
    value: _PublicationAction.finished,
    child: ListTile(
      leading: Icon(Icons.check_circle_outline),
      title: Text('Toggle finished'),
    ),
  ),
  PopupMenuItem(
    value: _PublicationAction.collection,
    child: ListTile(
      leading: Icon(Icons.playlist_add),
      title: Text('Add to collection'),
    ),
  ),
  if (publication.source.kind == LibrarySourceKind.local)
    PopupMenuItem(
      value: _PublicationAction.repair,
      child: ListTile(
        leading: Icon(Icons.build_outlined),
        title: Text('Repair local file'),
      ),
    ),
  PopupMenuDivider(),
  PopupMenuItem(
    value: _PublicationAction.delete,
    child: ListTile(
      leading: Icon(Icons.delete_outline),
      title: Text('Remove from library'),
    ),
  ),
];

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
