import 'package:fbooks/data/persistence/local_database.dart';
import 'package:fbooks/data/persistence/reading_locator_codec.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/reading_progress_repository.dart';

class DriftReadingProgressRepository implements ReadingProgressRepository {
  DriftReadingProgressRepository(this._database);

  final LocalDatabase _database;

  @override
  Future<ReadingProgress?> load(PublicationId publicationId) async {
    final row =
        await (_database.select(_database.storedReadingProgresses)..where(
              (progress) => progress.publicationId.equals(publicationId),
            ))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }

    return ReadingProgress(
      publicationId: row.publicationId,
      locator: ReadingLocatorCodec.decode(
        type: row.locatorType,
        value: row.locatorValue,
      ),
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> save(ReadingProgress progress) async {
    final locator = ReadingLocatorCodec.encode(progress.locator);
    await _database
        .into(_database.storedReadingProgresses)
        .insertOnConflictUpdate(
          StoredReadingProgressesCompanion.insert(
            publicationId: progress.publicationId,
            locatorType: locator.type,
            locatorValue: locator.value,
            updatedAt: progress.updatedAt,
          ),
        );
  }
}
