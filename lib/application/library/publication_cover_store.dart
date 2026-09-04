import 'dart:async';

import 'package:fbooks/application/managed_asset_store.dart';
import 'package:fbooks/application/library/publication_format_inspector.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:uuid/uuid.dart';

/// Persists generated cover images as Fbooks-managed publication assets.
class PublicationCoverStore {
  PublicationCoverStore(this._managedAssetStore, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final ManagedAssetStore _managedAssetStore;
  final Uuid _uuid;

  Future<PublicationAsset> save({
    required Publication publication,
    required CoverPayload payload,
  }) async {
    final assetId = _uuid.v4();
    final location = await _managedAssetStore.save(
      assetId: assetId,
      fileName: payload.fileName,
      bytes: Stream.value(payload.bytes),
    );
    return PublicationAsset(
      id: assetId,
      publicationId: publication.id,
      kind: PublicationAssetKind.coverImage,
      location: location,
      mediaType: payload.mediaType,
    );
  }

  /// Replaces only Fbooks-derived covers, retaining remote cover metadata.
  Publication replace(Publication publication, PublicationAsset? cover) {
    final generatedCoverLocations = publication.assets
        .where((asset) => asset.kind == PublicationAssetKind.coverImage)
        .map((asset) => asset.location)
        .toSet();
    final assets = publication.assets
        .where((asset) => asset.kind != PublicationAssetKind.coverImage)
        .toList();
    if (cover != null) {
      assets.add(cover);
    }
    return Publication(
      id: publication.id,
      source: publication.source,
      title: publication.title,
      authors: publication.authors,
      format: publication.format,
      description: publication.description,
      coverUri: generatedCoverLocations.contains(publication.coverUri)
          ? null
          : publication.coverUri,
      publishedAt: publication.publishedAt,
      tags: publication.tags,
      assets: assets,
      addedAt: publication.addedAt,
      lastReadAt: publication.lastReadAt,
    );
  }
}
