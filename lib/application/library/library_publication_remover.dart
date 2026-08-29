import 'package:fbooks/application/opds/opds_acquisition_importer.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding_repository.dart';
import 'package:logging/logging.dart';

final _logger = Logger('library.removal');

/// Removes a library record and, when requested, its app-managed OPDS download.
class LibraryPublicationRemover {
  LibraryPublicationRemover(
    this._repository,
    this._managedAssetStore,
    this._comicArchiveFileNameEncodingRepository,
  );

  final PublicationRepository _repository;
  final ManagedAssetStore _managedAssetStore;
  final ComicArchiveFileNameEncodingRepository
  _comicArchiveFileNameEncodingRepository;

  Future<PublicationRemovalResult> remove(
    PublicationId publicationId, {
    required bool deleteManagedFiles,
  }) async {
    final publication = await _repository.findById(publicationId);
    if (publication == null) {
      throw StateError('Publication $publicationId was not found');
    }

    final filesToDelete = managedFilesToDelete(
      publication,
      deleteManagedFiles: deleteManagedFiles,
    );
    await _repository.delete(publicationId);
    await _comicArchiveFileNameEncodingRepository.delete(publicationId);

    final filesNotDeleted = <Uri>[];
    for (final location in filesToDelete) {
      try {
        await _managedAssetStore.delete(location);
      } catch (error, stackTrace) {
        _logger.warning(
          'Managed download cleanup failed during removal: '
          'errorType=${error.runtimeType}.',
          null,
          stackTrace,
        );
        filesNotDeleted.add(location);
      }
    }
    _logger.info(
      'Publication removed: managedFilesNotDeleted=${filesNotDeleted.length}.',
    );
    return PublicationRemovalResult(
      publication: publication,
      filesNotDeleted: filesNotDeleted,
    );
  }
}

class PublicationRemovalResult {
  const PublicationRemovalResult({
    required this.publication,
    required this.filesNotDeleted,
  });

  final Publication publication;
  final List<Uri> filesNotDeleted;
}

/// Returns only download files created and owned by Fbooks.
List<Uri> managedDownloadFiles(Publication publication) {
  if (publication.source.kind != LibrarySourceKind.opds) {
    return const [];
  }
  return publication.assets
      .where(
        (asset) =>
            (asset.kind.isManagedByFbooks ||
                asset.kind == PublicationAssetKind.localFile) &&
            asset.location.scheme == 'file',
      )
      .map((asset) => asset.location)
      .toList(growable: false);
}

List<Uri> managedFilesToDelete(
  Publication publication, {
  required bool deleteManagedFiles,
}) {
  return publication.assets
      .where((asset) {
        final isCurrentManagedFile =
            asset.kind.isManagedByFbooks &&
            (publication.source.kind == LibrarySourceKind.local ||
                deleteManagedFiles);
        final isLegacyDownloadFile =
            deleteManagedFiles &&
            publication.source.kind == LibrarySourceKind.opds &&
            asset.kind == PublicationAssetKind.localFile;
        return asset.location.scheme == 'file' &&
            (isCurrentManagedFile || isLegacyDownloadFile);
      })
      .map((asset) => asset.location)
      .toList(growable: false);
}
