import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';

abstract interface class ReadingProgressRepository {
  Future<ReadingProgress?> load(PublicationId publicationId);

  Future<void> save(ReadingProgress progress);
}
