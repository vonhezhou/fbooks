import 'package:fbooks/app/providers.dart';
import 'package:fbooks/domain/collection/book_collection.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

Future<void> showCollectionMembershipManager(
  BuildContext context,
  WidgetRef ref,
  Set<PublicationId> publicationIds,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) =>
        _CollectionMembershipManager(publicationIds: publicationIds),
  );
}

class _CollectionMembershipManager extends ConsumerWidget {
  const _CollectionMembershipManager({required this.publicationIds});
  final Set<PublicationId> publicationIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom =
        ref.watch(bookCollectionsProvider).asData?.value ??
        const <BookCollection>[];
    final collections = [...SystemBookCollections.all, ...custom];
    final repository = ref.read(bookCollectionRepositoryProvider);
    return AlertDialog(
      title: const Text('Manage collections'),
      content: SizedBox(
        width: 440,
        height: 420,
        child: ListView(
          children: [
            for (final collection in collections)
              _MembershipTile(
                collection: collection,
                publicationIds: publicationIds,
                onDelete: collection.kind == BookCollectionKind.custom
                    ? () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete collection?'),
                            content: Text(
                              '“${collection.name}” will be deleted. The books themselves will stay in your library.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await repository.delete(collection.id);
                        }
                      }
                    : null,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final controller = TextEditingController();
            final name = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('New collection'),
                content: TextField(controller: controller, autofocus: true),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: const Text('Create'),
                  ),
                ],
              ),
            );
            if (name == null || name.isEmpty) return;
            final collection = BookCollection(
              id: const Uuid().v4(),
              name: name,
              kind: BookCollectionKind.custom,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await repository.save(collection);
            for (final id in publicationIds) {
              await repository.addPublication(collection.id, id);
            }
          },
          child: const Text('New collection'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _MembershipTile extends ConsumerStatefulWidget {
  const _MembershipTile({
    required this.collection,
    required this.publicationIds,
    this.onDelete,
  });
  final BookCollection collection;
  final Set<PublicationId> publicationIds;
  final VoidCallback? onDelete;
  @override
  ConsumerState<_MembershipTile> createState() => _MembershipTileState();
}

class _MembershipTileState extends ConsumerState<_MembershipTile> {
  bool? _value;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = await ref
        .read(bookCollectionRepositoryProvider)
        .listPublicationIds(widget.collection.id);
    if (mounted) {
      setState(
        () => _value = widget.publicationIds.every(ids.contains)
            ? true
            : widget.publicationIds.any(ids.contains)
            ? null
            : false,
      );
    }
  }

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    tristate: true,
    value: _value,
    title: Text(widget.collection.name),
    secondary: widget.onDelete == null
        ? const Icon(Icons.lock_outline)
        : IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: widget.onDelete,
          ),
    onChanged: (selected) async {
      final repository = ref.read(bookCollectionRepositoryProvider);
      for (final id in widget.publicationIds) {
        if (selected ?? false) {
          await repository.addPublication(widget.collection.id, id);
        } else {
          await repository.removePublication(widget.collection.id, id);
        }
      }
      if (mounted) {
        setState(() => _value = selected);
      }
    },
  );
}
