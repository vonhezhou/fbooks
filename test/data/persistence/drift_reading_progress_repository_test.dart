import 'package:drift/native.dart';
import 'package:fbooks/data/persistence/drift_publication_repository.dart';
import 'package:fbooks/data/persistence/drift_reading_progress_repository.dart';
import 'package:fbooks/data/persistence/local_database.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalDatabase database;

  setUp(() {
    database = LocalDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('persists and restores a comic reading position', () async {
    const publication = Publication(
      id: 'comic-1',
      source: LibrarySource(
        id: 'local-library',
        kind: LibrarySourceKind.local,
        name: 'Local library',
      ),
      title: 'Sample comic',
      format: PublicationFormat.comicArchive,
    );
    await DriftPublicationRepository(database).save(publication);
    final repository = DriftReadingProgressRepository(database);

    await repository.save(
      ReadingProgress(
        publicationId: publication.id,
        locator: const ComicPageLocator(12),
        updatedAt: DateTime(2026, 8, 26),
      ),
    );
    final restored = await repository.load(publication.id);

    expect(restored, isNotNull);
    expect(restored!.locator, isA<ComicPageLocator>());
    expect((restored.locator as ComicPageLocator).pageIndex, 12);
  });

  test('persists and restores a text chapter locator', () async {
    const publication = Publication(
      id: 'text-1',
      source: LibrarySource(
        id: 'local-library',
        kind: LibrarySourceKind.local,
        name: 'Local library',
      ),
      title: 'Sample text',
      format: PublicationFormat.epub,
    );
    await DriftPublicationRepository(database).save(publication);
    final repository = DriftReadingProgressRepository(database);

    await repository.save(
      ReadingProgress(
        publicationId: publication.id,
        locator: const TextOffsetLocator(chapterIndex: 4, offset: 0),
        updatedAt: DateTime(2026, 8, 26),
      ),
    );
    final restored = await repository.load(publication.id);

    expect(restored!.locator, isA<TextOffsetLocator>());
    expect((restored.locator as TextOffsetLocator).chapterIndex, 4);
  });
}
