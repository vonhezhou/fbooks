/// The origin of a publication in the user's library.
///
/// A [LibrarySource] describes where the publication was discovered. It does
/// not describe how it is stored locally; that is an infrastructure concern.
enum LibrarySourceKind { local, opds }

class LibrarySource {
  const LibrarySource({
    required this.id,
    required this.kind,
    required this.name,
  });

  final String id;
  final LibrarySourceKind kind;
  final String name;
}
