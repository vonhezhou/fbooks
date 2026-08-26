import 'package:fbooks/application/library/local_publication_importer.dart';
import 'package:fbooks/data/import/file_picker_local_publication_picker.dart';
import 'package:fbooks/data/persistence/drift_publication_repository.dart';
import 'package:fbooks/data/persistence/local_database.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(database.close);
  return database;
});

final publicationRepositoryProvider = Provider<PublicationRepository>((ref) {
  return DriftPublicationRepository(ref.watch(localDatabaseProvider));
});

final localPublicationPickerProvider = Provider<LocalPublicationPicker>((ref) {
  return FilePickerLocalPublicationPicker();
});

final localPublicationImporterProvider = Provider<LocalPublicationImporter>((
  ref,
) {
  return LocalPublicationImporter(ref.watch(publicationRepositoryProvider));
});

final libraryPublicationsProvider = StreamProvider<List<Publication>>((ref) {
  return ref.watch(publicationRepositoryProvider).watchPublications();
});
