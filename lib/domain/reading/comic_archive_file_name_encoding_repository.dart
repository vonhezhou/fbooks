import 'package:fbooks/domain/publication/publication_id.dart';

abstract interface class ComicArchiveFileNameEncodingRepository {
  Future<String?> load(PublicationId publicationId);

  Future<void> save(PublicationId publicationId, String? encodingName);

  Future<void> delete(PublicationId publicationId);
}
