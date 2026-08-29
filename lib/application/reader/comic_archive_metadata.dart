import 'package:fbooks/domain/publication/publication.dart';

class ComicArchiveMetadata {
  const ComicArchiveMetadata({this.title, this.author, this.description});

  final String? title;
  final String? author;
  final String? description;

  Publication applyTo(Publication publication) {
    final title = this.title?.trim();
    final author = this.author?.trim();
    final description = this.description?.trim();
    return Publication(
      id: publication.id,
      source: publication.source,
      title: title == null || title.isEmpty ? publication.title : title,
      authors: author == null || author.isEmpty
          ? publication.authors
          : [author],
      format: publication.format,
      description: description == null || description.isEmpty
          ? publication.description
          : description,
      coverUri: publication.coverUri,
      assets: publication.assets,
    );
  }
}

abstract interface class ComicArchiveMetadataReader {
  Future<ComicArchiveMetadata?> read(Uri location);
}
