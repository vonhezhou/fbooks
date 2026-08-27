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
  static const readingList = 'system:reading-list';
  static const favorites = 'system:favorites';
  static const saved = 'system:saved';

  static final all = <BookCollection>[
    BookCollection(
      id: readingList,
      name: 'Reading list',
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
      id: saved,
      name: 'Saved',
      kind: BookCollectionKind.system,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  ];
}
