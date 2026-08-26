import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';

class ReadingProgress {
  const ReadingProgress({
    required this.publicationId,
    required this.locator,
    required this.updatedAt,
  });

  final PublicationId publicationId;
  final ReadingLocator locator;
  final DateTime updatedAt;
}
