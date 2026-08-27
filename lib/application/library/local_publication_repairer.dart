import 'package:fbooks/application/library/local_publication_importer.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';

/// Repoints a missing locally imported publication at a replacement file.
class LocalPublicationRepairer {
  LocalPublicationRepairer(this._repository);

  final PublicationRepository _repository;

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
      (asset) => asset.kind == PublicationAssetKind.localFile,
    );
    if (assetIndex < 0) {
      throw StateError('Publication $publicationId has no local file asset');
    }
    final repairedAssets = [...publication.assets];
    final asset = repairedAssets[assetIndex];
    repairedAssets[assetIndex] = PublicationAsset(
      id: asset.id,
      publicationId: asset.publicationId,
      kind: asset.kind,
      location: replacement.location,
      mediaType: PublicationFormatDetector.mediaTypeFor(replacementFormat),
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
    return repaired;
  }
}
