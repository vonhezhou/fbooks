import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';

/// Port implemented by local and remote-backed library infrastructure.
abstract interface class PublicationRepository {
  Future<List<Publication>> listPublications();

  Future<Publication?> findById(PublicationId id);

  Future<Publication?> findByAssetLocation(Uri location);

  Future<void> save(Publication publication);

  Future<void> delete(PublicationId id);

  Stream<List<Publication>> watchPublications();
}
