import 'package:fbooks/domain/collection/book_collection.dart';
import 'package:fbooks/domain/publication/publication_id.dart';

/// Port for durable collections and their publication memberships.
abstract interface class BookCollectionRepository {
  Future<List<BookCollection>> listCollections();

  Future<BookCollection?> findById(String id);

  Future<void> save(BookCollection collection);

  Future<void> delete(String id);

  Future<List<PublicationId>> listPublicationIds(String collectionId);

  Future<void> addPublication(String collectionId, PublicationId publicationId);

  Future<void> removePublication(
    String collectionId,
    PublicationId publicationId,
  );

  Stream<List<BookCollection>> watchCollections();

  Stream<List<PublicationId>> watchPublicationIds(String collectionId);
}
