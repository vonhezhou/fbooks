import 'package:fbooks/domain/publication/publication.dart';

/// Port implemented by local and remote-backed library infrastructure.
abstract interface class PublicationRepository {
  Future<List<Publication>> listPublications();

  Future<Publication?> findById(PublicationId id);

  Stream<List<Publication>> watchPublications();
}
