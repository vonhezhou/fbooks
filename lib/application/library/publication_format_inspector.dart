import 'dart:typed_data';

import 'package:fbooks/domain/publication/publication.dart';

/// Metadata and preview resources discovered inside a readable publication.
class PublicationInspection {
  const PublicationInspection({this.metadata, this.cover});

  final PublicationMetadataPatch? metadata;
  final CoverPayload? cover;
}

/// A non-persistent update for metadata embedded in a publication file.
class PublicationMetadataPatch {
  const PublicationMetadataPatch({this.title, this.authors, this.description});

  final String? title;
  final List<String>? authors;
  final String? description;

  Publication applyTo(Publication publication) => Publication(
    id: publication.id,
    source: publication.source,
    title: title ?? publication.title,
    authors: authors ?? publication.authors,
    format: publication.format,
    description: description ?? publication.description,
    coverUri: publication.coverUri,
    assets: publication.assets,
    addedAt: publication.addedAt,
    lastReadAt: publication.lastReadAt,
  );
}

/// A cover image extracted or rendered by a format-specific inspector.
class CoverPayload {
  const CoverPayload({
    required this.fileName,
    required this.bytes,
    this.mediaType,
  });

  final String fileName;
  final Uint8List bytes;
  final String? mediaType;
}

/// Inspects one or more publication formats without persisting any result.
abstract interface class PublicationFormatInspector {
  bool supports(PublicationFormat format);

  Future<PublicationInspection?> inspect({
    required PublicationFormat format,
    required Uri location,
  });
}

/// Routes inspection to the adapter registered for the publication format.
class PublicationInspectorRegistry implements PublicationFormatInspector {
  const PublicationInspectorRegistry(this._inspectors);

  final List<PublicationFormatInspector> _inspectors;

  @override
  bool supports(PublicationFormat format) =>
      _inspectors.any((inspector) => inspector.supports(format));

  @override
  Future<PublicationInspection?> inspect({
    required PublicationFormat format,
    required Uri location,
  }) {
    for (final inspector in _inspectors) {
      if (inspector.supports(format)) {
        return inspector.inspect(format: format, location: location);
      }
    }
    return Future.value();
  }
}
