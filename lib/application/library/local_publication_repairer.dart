import 'dart:io';
import 'dart:typed_data';

import 'package:fbooks/application/managed_asset_store.dart';
import 'package:fbooks/application/library/local_publication_importer.dart';
import 'package:fbooks/application/library/publication_cover_store.dart';
import 'package:fbooks/application/library/publication_format_inspector.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding_repository.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

final _logger = Logger('library.repair');

/// Repoints a missing locally imported publication at a replacement file.
class LocalPublicationRepairer {
  LocalPublicationRepairer(
    this._repository,
    this._managedAssetStore, {
    required this.comicArchiveFileNameEncodingRepository,
    this.publicationFormatInspector,
    this.publicationCoverStore,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final PublicationRepository _repository;
  final ManagedAssetStore _managedAssetStore;
  final ComicArchiveFileNameEncodingRepository
  comicArchiveFileNameEncodingRepository;
  final PublicationFormatInspector? publicationFormatInspector;
  final PublicationCoverStore? publicationCoverStore;
  final Uuid _uuid;

  Future<Publication> repair({
    required PublicationId publicationId,
    required LocalPublicationCandidate replacement,
  }) async {
    final publication = await _repository.findById(publicationId);
    if (publication == null) {
      throw StateError('Publication $publicationId was not found');
    }
    if (publication.source.kind != LibrarySourceKind.local) {
      throw ArgumentError.value(
        publicationId,
        'publicationId',
        'Only locally imported publications can be repaired',
      );
    }
    final replacementFormat = PublicationFormatDetector.fromFileName(
      replacement.fileName,
    );
    if (replacementFormat == null || replacementFormat != publication.format) {
      throw ArgumentError.value(
        replacement.fileName,
        'replacement',
        'must have the same format as the publication',
      );
    }
    final existing = await _repository.findByAssetLocation(
      replacement.location,
    );
    if (existing != null && existing.id != publication.id) {
      throw StateError(
        'The selected file already belongs to ${existing.title}',
      );
    }

    final assetIndex = publication.assets.indexWhere(
      (asset) => asset.kind.isReadableLocalFile,
    );
    if (assetIndex < 0) {
      throw StateError('Publication $publicationId has no local file asset');
    }
    final previousAsset = publication.assets[assetIndex];
    final managedAssetId = _uuid.v4();
    final managedLocations = <Uri>[];
    try {
      final managedLocation = await _managedAssetStore.save(
        assetId: managedAssetId,
        fileName: replacement.fileName,
        bytes: File.fromUri(replacement.location)
            .openRead()
            .map(Uint8List.fromList),
      );
      managedLocations.add(managedLocation);
      final inspection = await publicationFormatInspector?.inspect(
        format: publication.format,
        location: managedLocation,
      );
      final previousCoverAssets = publication.assets
          .where((asset) => asset.kind == PublicationAssetKind.coverImage)
          .toList(growable: false);
      final repairedAssets = publication.assets
          .where((asset) => !asset.kind.isReadableLocalFile)
          .toList();
      final sourceAssetIndex = repairedAssets.indexWhere(
        (asset) => asset.kind == PublicationAssetKind.importedSource,
      );
      final sourceAsset = PublicationAsset(
        id: sourceAssetIndex < 0
            ? _uuid.v4()
            : repairedAssets[sourceAssetIndex].id,
        publicationId: publication.id,
        kind: PublicationAssetKind.importedSource,
        location: replacement.location,
        mediaType: PublicationFormatDetector.mediaTypeFor(replacementFormat),
      );
      if (sourceAssetIndex < 0) {
        repairedAssets.add(sourceAsset);
      } else {
        repairedAssets[sourceAssetIndex] = sourceAsset;
      }
      repairedAssets.add(
        PublicationAsset(
          id: managedAssetId,
          publicationId: publication.id,
          kind: PublicationAssetKind.managedFile,
          location: managedLocation,
          mediaType: PublicationFormatDetector.mediaTypeFor(replacementFormat),
        ),
      );
      var repaired = Publication(
        id: publication.id,
        source: publication.source,
        title: publication.title,
        authors: publication.authors,
        format: publication.format,
        description: publication.description,
        coverUri: publication.coverUri,
        publishedAt: publication.publishedAt,
        tags: publication.tags,
        assets: repairedAssets,
      );
      if (inspection?.metadata case final metadata?) {
        repaired = metadata.applyTo(repaired);
      }
      if (publicationCoverStore != null) {
        PublicationAsset? coverAsset;
        if (inspection?.cover case final cover?) {
          coverAsset = await publicationCoverStore!.save(
            publication: repaired,
            payload: cover,
          );
          managedLocations.add(coverAsset.location);
        }
        repaired = publicationCoverStore!.replace(repaired, coverAsset);
      }
      await _repository.save(repaired);
      await comicArchiveFileNameEncodingRepository.delete(publicationId);
      if (previousAsset.kind.isManagedByFbooks) {
        try {
          await _managedAssetStore.delete(previousAsset.location);
        } catch (cleanupError, cleanupStackTrace) {
          _logger.warning(
            'Previous managed asset cleanup failed after repair: '
            'errorType=${cleanupError.runtimeType}.',
            null,
            cleanupStackTrace,
          );
        }
      }
      for (final previousCover in previousCoverAssets) {
        if (!previousCover.kind.isManagedByFbooks) {
          continue;
        }
        try {
          await _managedAssetStore.delete(previousCover.location);
        } catch (cleanupError, cleanupStackTrace) {
          _logger.warning(
            'Previous generated cover cleanup failed after repair: '
            'errorType=${cleanupError.runtimeType}.',
            null,
            cleanupStackTrace,
          );
        }
      }
      _logger.info('Local publication repair completed.');
      return repaired;
    } catch (error, stackTrace) {
      _logger.severe(
        'Local publication repair failed: errorType=${error.runtimeType}.',
        null,
        stackTrace,
      );
      for (final managedLocation in managedLocations.reversed) {
        try {
          await _managedAssetStore.delete(managedLocation);
        } catch (cleanupError, cleanupStackTrace) {
          _logger.warning(
            'Local publication repair cleanup failed: '
            'errorType=${cleanupError.runtimeType}.',
            null,
            cleanupStackTrace,
          );
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
