import 'package:fbooks/application/opds/opds_acquisition_importer.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';

/// Removes a library record and, when requested, its app-managed OPDS download.
class LibraryPublicationRemover {
  LibraryPublicationRemover(this._repository, this._managedAssetStore);

  final PublicationRepository _repository;
  final ManagedAssetStore _managedAssetStore;

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

    final filesNotDeleted = <Uri>[];
    for (final location in filesToDelete) {
      try {
        await _managedAssetStore.delete(location);
      } catch (_) {
        filesNotDeleted.add(location);
      }
    }
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
