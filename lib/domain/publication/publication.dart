import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_id.dart';

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
    this.publishedAt,
    this.tags = const [],
    this.assets = const [],
    this.addedAt,
    this.lastReadAt,
  });

  final PublicationId id;
  final LibrarySource source;
  final String title;
  final List<String> authors;
  final PublicationFormat format;
  final String? description;
  final Uri? coverUri;
  final DateTime? publishedAt;
  final List<String> tags;
  final List<PublicationAsset> assets;
  final DateTime? addedAt;
  final DateTime? lastReadAt;
}
