import 'package:fbooks/domain/library/library_source.dart';

typedef PublicationId = String;

/// The file family determines which reader and reading locator can be used.
enum PublicationFormat { comicArchive, comicDirectory, epub, pdf, text }

/// A user-visible publication independent of its database or file-system form.
class Publication {
  const Publication({
    required this.id,
    required this.source,
    required this.title,
    required this.format,
    this.authors = const [],
    this.description,
    this.coverUri,
  });

  final PublicationId id;
  final LibrarySource source;
  final String title;
  final List<String> authors;
  final PublicationFormat format;
  final String? description;
  final Uri? coverUri;
}
