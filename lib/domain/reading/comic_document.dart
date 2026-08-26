import 'package:fbooks/domain/publication/publication_id.dart';

class ComicDocument {
  const ComicDocument({required this.publicationId, required this.pages});

  final PublicationId publicationId;
  final List<ComicPageDescriptor> pages;
}

class ComicPageDescriptor {
  const ComicPageDescriptor({required this.index, required this.name});

  final int index;
  final String name;
}
