import 'dart:io';
import 'dart:typed_data';

import 'package:fbooks/application/library/local_publication_importer.dart';
import 'package:fbooks/application/opds/opds_acquisition_importer.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:uuid/uuid.dart';

/// Repoints a missing locally imported publication at a replacement file.
class LocalPublicationRepairer {
  LocalPublicationRepairer(
    this._repository,
    this._managedAssetStore, {
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final PublicationRepository _repository;
  final ManagedAssetStore _managedAssetStore;
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
    Uri? managedLocation;
    try {
      managedLocation = await _managedAssetStore.save(
        assetId: managedAssetId,
        fileName: replacement.fileName,
        bytes: File.fromUri(replacement.location)
            .openRead()
            .map(Uint8List.fromList),
      );
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
      final repaired = Publication(
        id: publication.id,
        source: publication.source,
        title: publication.title,
        authors: publication.authors,
        format: publication.format,
        description: publication.description,
        coverUri: publication.coverUri,
        assets: repairedAssets,
      );
      await _repository.save(repaired);
      if (previousAsset.kind.isManagedByFbooks) {
        await _managedAssetStore.delete(previousAsset.location);
      }
      return repaired;
    } catch (_) {
      if (managedLocation != null) {
        await _managedAssetStore.delete(managedLocation);
      }
      rethrow;
    }
  }
}
