import 'dart:ui' as ui;

import 'package:fbooks/app/providers.dart';
import 'package:fbooks/app/window/window_caption.dart';
import 'package:fbooks/domain/collection/book_collection.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/features/library/presentation/publication_cover.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/features/collections/presentation/collection_membership_manager.dart';
import 'package:fbooks/features/reader/presentation/comic_reader_page.dart';
import 'package:fbooks/features/reader/presentation/pdf_reader_page.dart';
import 'package:fbooks/features/reader/presentation/flow_reader_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

const _collectionCardFooterExtent = 96.0;

/// The collection library mirrors the playlist-style Figma screen, while using
/// the user's real publications and durable local memberships.
class CollectionsPage extends ConsumerWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customCollections = ref.watch(bookCollectionsProvider);
    return customCollections.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Unable to load collections: $error')),
      data: (custom) => _CollectionsView(customCollections: custom),
    );
  }
}

class _CollectionsView extends ConsumerWidget {
  const _CollectionsView({required this.customCollections});

  final List<BookCollection> customCollections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverList.list(
            children: [
              for (final collection in SystemBookCollections.all)
                _SystemCollectionTile(collection: collection),
            ],
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Created collections ${customCollections.length}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'New collection',
                  onPressed: () => _showCollectionEditor(context, ref),
                  icon: const Icon(Icons.add, size: 20),
                ),
              ],
            ),
          ),
        ),
        if (customCollections.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyCollections(
              onCreate: () => _showCollectionEditor(context, ref),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.crossAxisExtent - 16) / 2;
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _CollectionCard(collection: customCollections[index]),
                    childCount: customCollections.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: tileWidth + _collectionCardFooterExtent,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SystemCollectionTile extends ConsumerWidget {
  const _SystemCollectionTile({required this.collection});

  final BookCollection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(collectionPublicationIdsProvider(collection.id));
    final icon = switch (collection.id) {
      SystemBookCollections.readLater => Icons.schedule_outlined,
      SystemBookCollections.favorites => Icons.favorite_border,
      SystemBookCollections.finished => Icons.check_circle_outline,
      _ => Icons.collections_bookmark_outlined,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minLeadingWidth: 24,
        leading: Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(
          collection.name,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${ids.asData?.value.length ?? 0}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: () => _openCollection(context, collection),
      ),
    );
  }
}

class _CollectionCard extends ConsumerWidget {
  const _CollectionCard({required this.collection});

  final BookCollection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(collectionPublicationIdsProvider(collection.id));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: () => _openCollection(context, collection),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: _CollectionCover(
                      collection: collection,
                      size: double.infinity,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  SizedBox(
                    height: _collectionCardFooterExtent,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            collection.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ids.asData?.value.length ?? 0} books',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(collection.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 10.4,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: PopupMenuButton<_CollectionAction>(
              tooltip: 'Collection actions',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: .4),
                foregroundColor: Colors.white,
                fixedSize: const Size.square(28),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onSelected: (action) =>
                  _handleCollectionAction(context, ref, collection, action),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _CollectionAction.edit,
                  child: Text('Edit'),
                ),
                PopupMenuItem(
                  value: _CollectionAction.delete,
                  child: Text('Delete'),
                ),
              ],
              icon: const Icon(Icons.more_vert, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class BookCollectionDetailPage extends ConsumerWidget {
  const BookCollectionDetailPage({super.key, required this.collection});

  final BookCollection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: const DesktopWindowCaption(),
    body: BookCollectionDetailContent(collection: collection),
  );
}

/// Renders a collection inside either a standalone route or the desktop shell.
class BookCollectionDetailContent extends ConsumerStatefulWidget {
  const BookCollectionDetailContent({
    super.key,
    required this.collection,
    this.showAppBar = true,
    this.desktopLayout,
  });

  final BookCollection collection;
  final bool showAppBar;
  final bool? desktopLayout;

  @override
  ConsumerState<BookCollectionDetailContent> createState() =>
      _BookCollectionDetailContentState();
}

enum _CollectionViewMode { cards, list }

enum _CollectionSort { title, author, added }

class _BookCollectionDetailContentState
    extends ConsumerState<BookCollectionDetailContent> {
  var _viewMode = _CollectionViewMode.cards;
  var _sort = _CollectionSort.title;
  var _descending = false;
  var _selectionMode = false;
  final _selectedIds = <PublicationId>{};

  @override
  Widget build(BuildContext context) {
    final publications = ref.watch(libraryPublicationsProvider);
    final memberIds = ref.watch(
      collectionPublicationIdsProvider(widget.collection.id),
    );
    return publications.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Unable to load this collection: $error')),
      data: (allPublications) {
        final ids = memberIds.asData?.value ?? const <PublicationId>[];
        final byId = {
          for (final publication in allPublications)
            publication.id: publication,
        };
        final books = ids
            .map((id) => byId[id])
            .whereType<Publication>()
            .toList();
        int compare(Publication left, Publication right) => switch (_sort) {
          _CollectionSort.title => left.title.toLowerCase().compareTo(
            right.title.toLowerCase(),
          ),
          _CollectionSort.author =>
            (left.authors.isEmpty ? '' : left.authors.first)
                .toLowerCase()
                .compareTo(
                  (right.authors.isEmpty ? '' : right.authors.first)
                      .toLowerCase(),
                ),
          _CollectionSort.added => (left.addedAt ?? DateTime(0)).compareTo(
            right.addedAt ?? DateTime(0),
          ),
        };
        books.sort(
          (left, right) =>
              _descending ? -compare(left, right) : compare(left, right),
        );
        return _CollectionDetailView(
          collection: widget.collection,
          books: books,
          allPublications: allPublications,
          showAppBar: widget.showAppBar,
          desktopLayout: widget.desktopLayout,
          viewMode: _viewMode,
          sort: _sort,
          descending: _descending,
          onViewModeChanged: (value) => setState(() => _viewMode = value),
          onSortChanged: (value) => setState(() => _sort = value),
          onDescendingChanged: (value) => setState(() => _descending = value),
          selectionMode: _selectionMode,
          selectedIds: _selectedIds,
          onSelectionModeChanged: (value) => setState(() {
            _selectionMode = value;
            if (!value) _selectedIds.clear();
          }),
          onSelectionChanged: (id) => setState(() {
            if (!_selectedIds.add(id)) _selectedIds.remove(id);
          }),
          onSelectAll: () => setState(
            () => _selectedIds
              ..clear()
              ..addAll(books.map((book) => book.id)),
          ),
        );
      },
    );
  }
}

class _CollectionDetailView extends ConsumerWidget {
  const _CollectionDetailView({
    required this.collection,
    required this.books,
    required this.allPublications,
    required this.showAppBar,
    required this.desktopLayout,
    required this.viewMode,
    required this.sort,
    required this.descending,
    required this.onViewModeChanged,
    required this.onSortChanged,
    required this.onDescendingChanged,
    required this.selectionMode,
    required this.selectedIds,
    required this.onSelectionModeChanged,
    required this.onSelectionChanged,
    required this.onSelectAll,
  });

  final BookCollection collection;
  final List<Publication> books;
  final List<Publication> allPublications;
  final bool showAppBar;
  final bool? desktopLayout;
  final _CollectionViewMode viewMode;
  final _CollectionSort sort;
  final bool descending;
  final ValueChanged<_CollectionViewMode> onViewModeChanged;
  final ValueChanged<_CollectionSort> onSortChanged;
  final ValueChanged<bool> onDescendingChanged;
  final bool selectionMode;
  final Set<PublicationId> selectedIds;
  final ValueChanged<bool> onSelectionModeChanged;
  final ValueChanged<PublicationId> onSelectionChanged;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = desktopLayout ?? MediaQuery.sizeOf(context).width >= 900;
      return _buildScrollView(context, ref, desktop: desktop);
    },
  );

  Widget _buildScrollView(
    BuildContext context,
    WidgetRef ref, {
    required bool desktop,
  }) {
    final canStartReading = books.any(_isReadable);
    return CustomScrollView(
      slivers: [
        if (showAppBar)
          SliverAppBar(
            pinned: true,
            toolbarHeight: desktop ? 64 : kToolbarHeight,
            title: Text(collection.name),
            actions: [
              IconButton(
                tooltip: selectionMode ? 'Done selecting' : 'Select books',
                onPressed: () => onSelectionModeChanged(!selectionMode),
                icon: Icon(selectionMode ? Icons.close : Icons.checklist),
              ),
              if (selectionMode)
                TextButton(onPressed: onSelectAll, child: const Text('All')),
              if (selectionMode)
                IconButton(
                  tooltip: 'Manage collections',
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => showCollectionMembershipManager(
                          context,
                          ref,
                          selectedIds,
                        ),
                  icon: const Icon(Icons.playlist_add),
                ),
              if (selectionMode)
                IconButton(
                  tooltip: 'Remove selected books',
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () async {
                          final repository = ref.read(
                            bookCollectionRepositoryProvider,
                          );
                          for (final id in selectedIds) {
                            await repository.removePublication(
                              collection.id,
                              id,
                            );
                          }
                          onSelectionModeChanged(false);
                        },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              PopupMenuButton<_CollectionSort>(
                tooltip: 'Sort books',
                initialValue: sort,
                onSelected: onSortChanged,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _CollectionSort.title,
                    child: Text('Title'),
                  ),
                  PopupMenuItem(
                    value: _CollectionSort.author,
                    child: Text('Author'),
                  ),
                  PopupMenuItem(
                    value: _CollectionSort.added,
                    child: Text('Added time'),
                  ),
                ],
              ),
              IconButton(
                tooltip: descending ? 'Ascending' : 'Descending',
                onPressed: () => onDescendingChanged(!descending),
                icon: Icon(descending ? Icons.south : Icons.north),
              ),
              IconButton(
                tooltip: viewMode == _CollectionViewMode.cards
                    ? 'Show list'
                    : 'Show cards',
                onPressed: () => onViewModeChanged(
                  viewMode == _CollectionViewMode.cards
                      ? _CollectionViewMode.list
                      : _CollectionViewMode.cards,
                ),
                icon: Icon(
                  viewMode == _CollectionViewMode.cards
                      ? Icons.view_list_outlined
                      : Icons.grid_view_outlined,
                ),
              ),
              IconButton(
                tooltip: 'Add books',
                onPressed: () => _showMembershipEditor(
                  context,
                  ref,
                  collection,
                  allPublications,
                  books.map((book) => book.id).toSet(),
                ),
                icon: const Icon(Icons.library_add_outlined),
              ),
            ],
          ),
        SliverToBoxAdapter(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      image: collection.coverUri == null
                          ? null
                          : DecorationImage(
                              image: NetworkImage(
                                collection.coverUri.toString(),
                              ),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withValues(alpha: .45),
                        Colors.black.withValues(alpha: .72),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                key: desktop
                    ? const Key('collection-detail-desktop-content')
                    : null,
                padding: EdgeInsets.fromLTRB(
                  desktop ? 32 : 24,
                  desktop ? 32 : 56,
                  desktop ? 32 : 24,
                  24,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = desktop;
                    final cover = _CollectionCover(
                      collection: collection,
                      size: isWide ? 196 : 156,
                    );
                    final details = _CollectionDetails(
                      collection: collection,
                      bookCount: books.length,
                      centered: !isWide,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              cover,
                              const SizedBox(width: 24),
                              Expanded(child: details),
                            ],
                          )
                        else
                          Column(
                            children: [
                              cover,
                              const SizedBox(height: 16),
                              details,
                            ],
                          ),
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: isWide
                              ? WrapAlignment.start
                              : WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: canStartReading
                                  ? () => _openFirstReadable(context, books)
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1C1B1F),
                              ),
                              icon: const Icon(Icons.menu_book_outlined),
                              label: const Text('Start reading'),
                            ),
                            if (!showAppBar)
                              IconButton(
                                tooltip: 'Manage books',
                                onPressed: () => _showMembershipEditor(
                                  context,
                                  ref,
                                  collection,
                                  allPublications,
                                  books.map((book) => book.id).toSet(),
                                ),
                                color: Colors.white70,
                                icon: const Icon(Icons.more_vert),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final horizontal = desktop ? 32.0 : 16.0;
            final columns = MediaQuery.sizeOf(context).width < 600
                ? 2
                : MediaQuery.sizeOf(context).width < 900
                ? 3
                : 5;
            final spacing = desktop ? 24.0 : 16.0;
            final tileWidth =
                (constraints.crossAxisExtent -
                    horizontal * 2 -
                    spacing * (columns - 1)) /
                columns;
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 36),
              sliver: books.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyCollectionDetail(
                        onAdd: () => _showMembershipEditor(
                          context,
                          ref,
                          collection,
                          allPublications,
                          const {},
                        ),
                      ),
                    )
                  : viewMode == _CollectionViewMode.cards && !selectionMode
                  ? SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _BookCard(book: books[index]),
                        childCount: books.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: tileWidth / (3 / 4) + 72,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                      ),
                    )
                  : SliverList.separated(
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return ListTile(
                          leading: selectionMode
                              ? Checkbox(
                                  value: selectedIds.contains(book.id),
                                  onChanged: (_) => onSelectionChanged(book.id),
                                )
                              : SizedBox(
                                  width: 36,
                                  height: 52,
                                  child: PublicationCover(publication: book),
                                ),
                          title: Text(book.title),
                          subtitle: Text(
                            book.authors.isEmpty
                                ? _formatName(book.format)
                                : book.authors.join(', '),
                          ),
                          trailing: IconButton(
                            tooltip: 'Remove from this collection',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => ref
                                .read(bookCollectionRepositoryProvider)
                                .removePublication(collection.id, book.id),
                          ),
                          onTap: selectionMode
                              ? () => onSelectionChanged(book.id)
                              : _isReadable(book)
                              ? () => _openPublication(context, book)
                              : null,
                        );
                      },
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                    ),
            );
          },
        ),
      ],
    );
  }
}

class _CollectionDetails extends StatelessWidget {
  const _CollectionDetails({
    required this.collection,
    required this.bookCount,
    required this.centered,
  });

  final BookCollection collection;
  final int bookCount;
  final bool centered;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Text(
        collection.kind == BookCollectionKind.system
            ? 'SYSTEM COLLECTION'
            : 'COLLECTION',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Colors.white70, letterSpacing: 1.5),
      ),
      const SizedBox(height: 4),
      Text(
        collection.name,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: Colors.white,
          fontSize: centered ? 24 : 34,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
      ),
      if (collection.description case final description?) ...[
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            description,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      ],
      const SizedBox(height: 8),
      Text(
        '$bookCount books · Created ${_formatDate(collection.createdAt)}',
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Colors.white70),
      ),
    ],
  );
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});

  final Publication book;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: _isReadable(book) ? () => _openPublication(context, book) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: PublicationCover(
              publication: book,
              borderRadius: BorderRadius.zero,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  book.authors.isEmpty
                      ? _formatName(book.format)
                      : book.authors.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CollectionCover extends StatelessWidget {
  const _CollectionCover({
    required this.collection,
    required this.size,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final BookCollection collection;
  final double size;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => Container(
    width: size.isFinite ? size : null,
    height: size.isFinite ? size : null,
    decoration: BoxDecoration(
      color: collection.kind == BookCollectionKind.system
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: borderRadius,
      image: collection.coverUri == null
          ? null
          : DecorationImage(
              image: NetworkImage(collection.coverUri.toString()),
              fit: BoxFit.cover,
            ),
    ),
    child: collection.coverUri == null
        ? Icon(
            switch (collection.id) {
              SystemBookCollections.readLater => Icons.schedule_outlined,
              SystemBookCollections.favorites => Icons.favorite,
              SystemBookCollections.finished => Icons.check_circle,
              _ => Icons.image_outlined,
            },
            size: size.isFinite ? 64 : 40,
            color: collection.kind == BookCollectionKind.system
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          )
        : null,
  );
}

class _EmptyCollections extends StatelessWidget {
  const _EmptyCollections({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_mosaic_outlined, size: 56),
          const SizedBox(height: 14),
          Text(
            'Make a collection',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Group books you want to revisit, share, or read next.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onCreate,
            child: const Text('Create collection'),
          ),
        ],
      ),
    ),
  );
}

class _EmptyCollectionDetail extends StatelessWidget {
  const _EmptyCollectionDetail({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.menu_book_outlined, size: 56),
        const SizedBox(height: 14),
        Text(
          'No books here yet',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          'Add publications from your library to begin.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add books'),
        ),
      ],
    ),
  );
}

enum _CollectionAction { edit, delete }

Future<void> _handleCollectionAction(
  BuildContext context,
  WidgetRef ref,
  BookCollection collection,
  _CollectionAction action,
) async {
  switch (action) {
    case _CollectionAction.edit:
      await _showCollectionEditor(context, ref, collection: collection);
    case _CollectionAction.delete:
      final delete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete collection?'),
          content: Text(
            '“${collection.name}” will be removed. Your books will stay in the library.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (delete == true) {
        await ref.read(bookCollectionRepositoryProvider).delete(collection.id);
      }
  }
}

Future<void> _showCollectionEditor(
  BuildContext context,
  WidgetRef ref, {
  BookCollection? collection,
}) async {
  final nameController = TextEditingController(text: collection?.name);
  final descriptionController = TextEditingController(
    text: collection?.description,
  );
  final result = await showDialog<(String, String?)>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(collection == null ? 'New collection' : 'Edit collection'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isNotEmpty) {
              final description = descriptionController.text.trim();
              Navigator.pop(context, (
                name,
                description.isEmpty ? null : description,
              ));
            }
          },
          child: Text(collection == null ? 'Create' : 'Save'),
        ),
      ],
    ),
  );
  nameController.dispose();
  descriptionController.dispose();
  if (result == null) {
    return;
  }
  final now = DateTime.now();
  await ref
      .read(bookCollectionRepositoryProvider)
      .save(
        BookCollection(
          id: collection?.id ?? const Uuid().v4(),
          name: result.$1,
          description: result.$2,
          kind: BookCollectionKind.custom,
          createdAt: collection?.createdAt ?? now,
          updatedAt: now,
          coverUri: collection?.coverUri,
        ),
      );
}

Future<void> _showMembershipEditor(
  BuildContext context,
  WidgetRef ref,
  BookCollection collection,
  List<Publication> allBooks,
  Set<PublicationId> selected,
) async {
  final nextSelection = {...selected};
  final result = await showDialog<Set<PublicationId>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Edit books'),
        content: SizedBox(
          width: 440,
          height: 420,
          child: allBooks.isEmpty
              ? const Center(
                  child: Text('Import a book into the library first.'),
                )
              : ListView(
                  children: [
                    for (final book in allBooks)
                      CheckboxListTile(
                        value: nextSelection.contains(book.id),
                        onChanged: (selected) => setDialogState(() {
                          if (selected ?? false) {
                            nextSelection.add(book.id);
                          } else {
                            nextSelection.remove(book.id);
                          }
                        }),
                        title: Text(book.title),
                        subtitle: Text(
                          book.authors.isEmpty
                              ? _formatName(book.format)
                              : book.authors.join(', '),
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nextSelection),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (result == null) {
    return;
  }
  final repository = ref.read(bookCollectionRepositoryProvider);
  for (final id in selected.difference(result)) {
    await repository.removePublication(collection.id, id);
  }
  for (final id in result.difference(selected)) {
    await repository.addPublication(collection.id, id);
  }
}

void _openCollection(BuildContext context, BookCollection collection) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => BookCollectionDetailPage(collection: collection),
    ),
  );
}

void _openFirstReadable(BuildContext context, List<Publication> books) {
  final book = books.where(_isReadable).firstOrNull;
  if (book != null) {
    _openPublication(context, book);
  }
}

bool _isReadable(Publication publication) => switch (publication.format) {
  PublicationFormat.comicArchive ||
  PublicationFormat.comicDirectory ||
  PublicationFormat.epub ||
  PublicationFormat.pdf ||
  PublicationFormat.text => true,
};

void _openPublication(BuildContext context, Publication publication) {
  final page = switch (publication.format) {
    PublicationFormat.comicArchive || PublicationFormat.comicDirectory =>
      ComicReaderPage(publicationId: publication.id, title: publication.title),
    PublicationFormat.epub || PublicationFormat.text => FlowReaderPage(
      publicationId: publication.id,
      title: publication.title,
    ),
    PublicationFormat.pdf => PdfReaderPage(
      publicationId: publication.id,
      title: publication.title,
    ),
  };
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (context) => page));
}

String _formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

String _formatName(PublicationFormat format) => switch (format) {
  PublicationFormat.comicArchive || PublicationFormat.comicDirectory => 'Comic',
  PublicationFormat.epub => 'EPUB',
  PublicationFormat.text => 'Text',
  PublicationFormat.pdf => 'PDF',
};
