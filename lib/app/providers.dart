import 'package:fbooks/application/library/local_publication_importer.dart';
import 'package:fbooks/application/opds/opds_catalog.dart';
import 'package:fbooks/application/opds/opds_catalog_client.dart';
import 'package:fbooks/application/reader/comic_reader_session.dart';
import 'package:fbooks/application/reader/text_reader_session.dart';
import 'package:fbooks/data/import/file_picker_local_publication_picker.dart';
import 'package:fbooks/data/persistence/drift_publication_repository.dart';
import 'package:fbooks/data/persistence/drift_reading_progress_repository.dart';
import 'package:fbooks/data/persistence/drift_library_source_repository.dart';
import 'package:fbooks/data/persistence/local_database.dart';
import 'package:fbooks/data/opds/http_opds_catalog_client.dart';
import 'package:fbooks/data/reader/archive_comic_reader_session.dart';
import 'package:fbooks/data/reader/local_text_reader_session.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:fbooks/domain/library/library_source_repository.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/reading_progress_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(database.close);
  return database;
});

final publicationRepositoryProvider = Provider<PublicationRepository>((ref) {
  return DriftPublicationRepository(ref.watch(localDatabaseProvider));
});

final librarySourceRepositoryProvider = Provider<LibrarySourceRepository>(
  (ref) => DriftLibrarySourceRepository(ref.watch(localDatabaseProvider)),
);

final opdsHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final opdsCatalogClientProvider = Provider<OpdsCatalogClient>((ref) {
  return HttpOpdsCatalogClient(ref.watch(opdsHttpClientProvider));
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

final textReaderSessionFactoryProvider = Provider<TextReaderSessionFactory>(
  (ref) => LocalTextReaderSessionFactory(),
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

final textReaderSessionProvider =
    FutureProvider.family<TextReaderSession, PublicationId>((
      ref,
      publicationId,
    ) async {
      final publication = await ref
          .watch(publicationRepositoryProvider)
          .findById(publicationId);
      if (publication == null) {
        throw StateError('Publication $publicationId was not found');
      }
      return ref.watch(textReaderSessionFactoryProvider).open(publication);
    });

final opdsCatalogProvider = FutureProvider.family<OpdsCatalog, Uri>(
  (ref, endpoint) => ref.watch(opdsCatalogClientProvider).fetch(endpoint),
);
