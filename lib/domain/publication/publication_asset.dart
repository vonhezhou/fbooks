import 'package:fbooks/domain/publication/publication_id.dart';

/// A readable representation of a [Publication].
///
/// The same publication can later have both an OPDS acquisition URL and an
/// offline file cache, so assets are modeled independently from metadata.
enum PublicationAssetKind {
  localFile,
  managedFile,
  importedSource,
  remoteAcquisition,
  coverImage,
}

extension PublicationAssetKindX on PublicationAssetKind {
  bool get isReadableLocalFile =>
      this == PublicationAssetKind.localFile ||
      this == PublicationAssetKind.managedFile;

  bool get isManagedByFbooks =>
      this == PublicationAssetKind.managedFile ||
      this == PublicationAssetKind.coverImage;
}

class PublicationAsset {
  const PublicationAsset({
    required this.id,
    required this.publicationId,
    required this.kind,
    required this.location,
    this.mediaType,
  });

  final String id;
  final PublicationId publicationId;
  final PublicationAssetKind kind;
  final Uri location;
  final String? mediaType;
}
