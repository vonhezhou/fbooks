import 'package:fbooks/application/library/local_publication_importer.dart';
import 'package:fbooks/application/reader/comic_reader_session.dart';
import 'package:fbooks/data/import/file_picker_local_publication_picker.dart';
import 'package:fbooks/data/persistence/drift_publication_repository.dart';
import 'package:fbooks/data/persistence/drift_reading_progress_repository.dart';
import 'package:fbooks/data/persistence/local_database.dart';
import 'package:fbooks/data/reader/archive_comic_reader_session.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/reading_progress_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(database.close);
  return database;
});

final publicationRepositoryProvider = Provider<PublicationRepository>((ref) {
  return DriftPublicationRepository(ref.watch(localDatabaseProvider));
});

final readingProgressRepositoryProvider = Provider<ReadingProgressRepository>(
  (ref) => DriftReadingProgressRepository(ref.watch(localDatabaseProvider)),
);

final localPublicationPickerProvider = Provider<LocalPublicationPicker>((ref) {
  return FilePickerLocalPublicationPicker();
});

final localPublicationImporterProvider = Provider<LocalPublicationImporter>((
  ref,
) {
  return LocalPublicationImporter(ref.watch(publicationRepositoryProvider));
});

final comicReaderSessionFactoryProvider = Provider<ComicReaderSessionFactory>(
  (ref) => ArchiveComicReaderSessionFactory(),
);

final libraryPublicationsProvider = StreamProvider<List<Publication>>((ref) {
  return ref.watch(publicationRepositoryProvider).watchPublications();
});

final comicReaderSessionProvider =
    FutureProvider.family<ComicReaderSession, PublicationId>((
      ref,
      publicationId,
    ) async {
      final publication = await ref
          .watch(publicationRepositoryProvider)
          .findById(publicationId);
      if (publication == null) {
        throw StateError('Publication $publicationId was not found');
      }
      return ref.watch(comicReaderSessionFactoryProvider).open(publication);
    });

final readingProgressProvider =
    FutureProvider.family<ReadingProgress?, PublicationId>((
      ref,
      publicationId,
    ) {
      return ref.watch(readingProgressRepositoryProvider).load(publicationId);
    });
