import 'dart:async';

import 'package:fbooks/application/managed_asset_store.dart';
import 'package:fbooks/application/library/local_publication_importer.dart';
import 'package:fbooks/application/library/local_publication_repairer.dart';
import 'package:fbooks/application/library/library_publication_remover.dart';
import 'package:fbooks/application/library/publication_cover_store.dart';
import 'package:fbooks/application/library/publication_format_inspector.dart';
import 'package:fbooks/application/opds/opds_catalog.dart';
import 'package:fbooks/application/opds/opds_catalog_request.dart';
import 'package:fbooks/application/opds/opds_credentials_repository.dart';
import 'package:fbooks/application/opds/opds_acquisition_importer.dart';
import 'package:fbooks/application/opds/opds_catalog_client.dart';
import 'package:fbooks/application/reader/comic_reader_session.dart';
import 'package:fbooks/application/reader/flow_reading_session.dart';
import 'package:fbooks/app/window/window_controller.dart';
import 'package:fbooks/data/import/file_picker_local_publication_picker.dart';
import 'package:fbooks/data/preferences/shared_preferences_comic_reading_preferences_repository.dart';
import 'package:fbooks/data/preferences/shared_preferences_comic_archive_file_name_encoding_repository.dart';
import 'package:fbooks/data/preferences/shared_preferences_text_reading_preferences_repository.dart';
import 'package:fbooks/data/preferences/shared_preferences_app_settings_repository.dart';
import 'package:fbooks/data/preferences/secure_opds_credentials_repository.dart';
import 'package:fbooks/data/persistence/drift_publication_repository.dart';
import 'package:fbooks/data/persistence/drift_book_collection_repository.dart';
import 'package:fbooks/data/persistence/drift_reading_progress_repository.dart';
import 'package:fbooks/data/persistence/drift_library_source_repository.dart';
import 'package:fbooks/data/persistence/local_database.dart';
import 'package:fbooks/data/opds/http_opds_catalog_client.dart';
import 'package:fbooks/data/opds/http_remote_asset_fetcher.dart';
import 'package:fbooks/data/reader/archive_comic_reader_session.dart';
import 'package:fbooks/data/reader/archive_comic_publication_inspector.dart';
import 'package:fbooks/data/reader/epub_publication_inspector.dart';
import 'package:fbooks/data/reader/local_flow_reading_session.dart';
import 'package:fbooks/data/reader/pdf_publication_inspector.dart';
import 'package:fbooks/data/reader/text_publication_inspector.dart';
import 'package:fbooks/data/storage/managed_asset_store.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:fbooks/domain/library/library_source_repository.dart';
import 'package:fbooks/domain/collection/book_collection.dart';
import 'package:fbooks/domain/collection/book_collection_repository.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/reading_progress_repository.dart';
import 'package:fbooks/domain/reading/comic_reading_preferences.dart';
import 'package:fbooks/domain/reading/comic_reading_preferences_repository.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding_repository.dart';
import 'package:fbooks/domain/reading/text_reading_preferences.dart';
import 'package:fbooks/domain/reading/text_reading_preferences_repository.dart';
import 'package:fbooks/domain/settings/app_settings.dart';
import 'package:fbooks/domain/settings/app_settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final appLogDirectoryProvider = Provider<String?>((ref) => null);

final appWindowControllerProvider = Provider<AppWindowController>((ref) {
  final controller = NoopWindowController();
  ref.onDispose(controller.dispose);
  return controller;
});

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

final bookCollectionRepositoryProvider = Provider<BookCollectionRepository>((
  ref,
) {
  return DriftBookCollectionRepository(ref.watch(localDatabaseProvider));
});

final opdsHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final opdsCatalogClientProvider = Provider<OpdsCatalogClient>((ref) {
  return HttpOpdsCatalogClient(ref.watch(opdsHttpClientProvider));
});

final remoteAssetFetcherProvider = Provider<RemoteAssetFetcher>((ref) {
  return HttpRemoteAssetFetcher(ref.watch(opdsHttpClientProvider));
});

final managedAssetStoreProvider = Provider<ManagedAssetStore>(
  (ref) => AppSupportManagedAssetStore(),
);

final opdsCredentialsRepositoryProvider = Provider<OpdsCredentialsRepository>(
  (ref) => SecureOpdsCredentialsRepository(),
);

final opdsAcquisitionImporterProvider = Provider<OpdsAcquisitionImporter>((
  ref,
) {
  return OpdsAcquisitionImporter(
    ref.watch(publicationRepositoryProvider),
    ref.watch(remoteAssetFetcherProvider),
    ref.watch(managedAssetStoreProvider),
    credentialsRepository: ref.watch(opdsCredentialsRepositoryProvider),
  );
});

final readingProgressRepositoryProvider = Provider<ReadingProgressRepository>(
  (ref) => DriftReadingProgressRepository(ref.watch(localDatabaseProvider)),
);

final comicReadingPreferencesRepositoryProvider =
    Provider<ComicReadingPreferencesRepository>(
      (ref) => SharedPreferencesComicReadingPreferencesRepository(),
    );

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return SharedPreferencesAppSettingsRepository();
});

final comicArchiveFileNameEncodingRepositoryProvider =
    Provider<ComicArchiveFileNameEncodingRepository>((ref) {
      return SharedPreferencesComicArchiveFileNameEncodingRepository();
    });

final publicationFormatInspectorProvider = Provider<PublicationFormatInspector>(
  (ref) => PublicationInspectorRegistry([
    ArchiveComicPublicationInspector(),
    EpubPublicationInspector(),
    PdfPublicationInspector(),
    TextPublicationInspector(),
  ]),
);

final publicationCoverStoreProvider = Provider<PublicationCoverStore>(
  (ref) => PublicationCoverStore(ref.watch(managedAssetStoreProvider)),
);

final textReadingPreferencesRepositoryProvider =
    Provider<TextReadingPreferencesRepository>((ref) {
      return SharedPreferencesTextReadingPreferencesRepository();
    });

final localPublicationPickerProvider = Provider<LocalPublicationPicker>((ref) {
  return FilePickerLocalPublicationPicker();
});

final localPublicationImporterProvider = Provider<LocalPublicationImporter>((
  ref,
) {
  return LocalPublicationImporter(
    ref.watch(publicationRepositoryProvider),
    ref.watch(managedAssetStoreProvider),
    publicationFormatInspector: ref.watch(publicationFormatInspectorProvider),
    publicationCoverStore: ref.watch(publicationCoverStoreProvider),
  );
});

final libraryPublicationRemoverProvider = Provider<LibraryPublicationRemover>(
  (ref) => LibraryPublicationRemover(
    ref.watch(publicationRepositoryProvider),
    ref.watch(managedAssetStoreProvider),
    ref.watch(comicArchiveFileNameEncodingRepositoryProvider),
  ),
);

final localPublicationRepairerProvider = Provider<LocalPublicationRepairer>(
  (ref) => LocalPublicationRepairer(
    ref.watch(publicationRepositoryProvider),
    ref.watch(managedAssetStoreProvider),
    comicArchiveFileNameEncodingRepository: ref.watch(
      comicArchiveFileNameEncodingRepositoryProvider,
    ),
    publicationFormatInspector: ref.watch(publicationFormatInspectorProvider),
    publicationCoverStore: ref.watch(publicationCoverStoreProvider),
  ),
);

final comicReaderSessionFactoryProvider = Provider<ComicReaderSessionFactory>(
  (ref) => ArchiveComicReaderSessionFactory(
    ref.watch(comicArchiveFileNameEncodingRepositoryProvider),
  ),
);

final flowReadingSessionFactoryProvider = Provider<FlowReadingSessionFactory>(
  (ref) => LocalFlowReadingSessionFactory(),
);

final libraryPublicationsProvider = StreamProvider<List<Publication>>((ref) {
  return ref.watch(publicationRepositoryProvider).watchPublications();
});

final bookCollectionsProvider = StreamProvider<List<BookCollection>>((ref) {
  return ref.watch(bookCollectionRepositoryProvider).watchCollections();
});

final collectionPublicationIdsProvider =
    StreamProvider.family<List<PublicationId>, String>((ref, collectionId) {
      return ref
          .watch(bookCollectionRepositoryProvider)
          .watchPublicationIds(collectionId);
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
      final session = await ref
          .watch(comicReaderSessionFactoryProvider)
          .open(publication);
      ref.onDispose(() => unawaited(session.close()));
      return session;
    });

final readingProgressProvider =
    FutureProvider.family<ReadingProgress?, PublicationId>((
      ref,
      publicationId,
    ) {
      return ref.watch(readingProgressRepositoryProvider).load(publicationId);
    });

final comicReadingPreferencesProvider = FutureProvider<ComicReadingPreferences>(
  (ref) {
    return ref.watch(comicReadingPreferencesRepositoryProvider).load();
  },
);

final appSettingsProvider = FutureProvider<AppSettings>((ref) {
  return ref.watch(appSettingsRepositoryProvider).load();
});

final textReadingPreferencesProvider = FutureProvider<TextReadingPreferences>(
  (ref) => ref.watch(textReadingPreferencesRepositoryProvider).load(),
);

final flowReadingSessionProvider =
    FutureProvider.family<FlowReadingSession, PublicationId>((
      ref,
      publicationId,
    ) async {
      final publication = await ref
          .watch(publicationRepositoryProvider)
          .findById(publicationId);
      if (publication == null) {
        throw StateError('Publication $publicationId was not found');
      }
      final session = await ref
          .watch(flowReadingSessionFactoryProvider)
          .open(publication);
      ref.onDispose(() => session.close());
      return session;
    });

final opdsCatalogProvider =
    FutureProvider.family<OpdsCatalog, OpdsCatalogRequest>((
      ref,
      request,
    ) async {
      final credentials = await ref
          .watch(opdsCredentialsRepositoryProvider)
          .load(request.sourceId);
      return ref
          .watch(opdsCatalogClientProvider)
          .fetch(request.endpoint, credentials: credentials);
    });
