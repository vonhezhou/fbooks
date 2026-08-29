/// A named, local grouping of publications in the user's library.
class BookCollection {
  const BookCollection({
    required this.id,
    required this.name,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.coverUri,
  });

  final String id;
  final String name;
  final BookCollectionKind kind;
  final String? description;
  final Uri? coverUri;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Built-in collections are kept separate from collections the user creates.
enum BookCollectionKind { system, custom }

/// Stable identifiers for the built-in collection shortcuts in the interface.
abstract final class SystemBookCollections {
  /// Kept stable so existing reading-list memberships become Read later.
  static const readLater = 'system:reading-list';
  static const favorites = 'system:favorites';
  static const finished = 'system:finished';

  static final all = <BookCollection>[
    BookCollection(
      id: readLater,
      name: 'Read later',
      kind: BookCollectionKind.system,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
    BookCollection(
      id: favorites,
      name: 'Favorites',
      kind: BookCollectionKind.system,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
    BookCollection(
      id: finished,
      name: 'Finished',
      kind: BookCollectionKind.system,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  ];
}
