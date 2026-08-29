import 'dart:io';

import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// Renders a publication's generated local, remote, or built-in cover.
class PublicationCover extends StatelessWidget {
  const PublicationCover({
    super.key,
    required this.publication,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  final Publication publication;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: _coverFor(_coverLocations()),
      ),
    );
  }

  List<Uri> _coverLocations() {
    final locations = <Uri>{
      ...publication.assets
          .where((asset) => asset.kind == PublicationAssetKind.coverImage)
          .map((asset) => asset.location),
    };
    final coverUri = publication.coverUri;
    if (coverUri != null) {
      locations.add(coverUri);
    }
    return locations.toList(growable: false);
  }

  Widget _coverFor(List<Uri> locations, [int index = 0]) {
    if (index >= locations.length) {
      return _fallback();
    }
    final image = _imageFor(locations[index]);
    if (image == null) {
      return _coverFor(locations, index + 1);
    }
    return Image(
      image: image,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _coverFor(locations, index + 1),
    );
  }

  ImageProvider<Object>? _imageFor(Uri coverUri) => switch (coverUri.scheme) {
    'file' => FileImage(File.fromUri(coverUri)),
    'http' || 'https' => NetworkImage(coverUri.toString()),
    _ => null,
  };

  Widget _fallback() => Assets.images.defaultBookCover.image(
    fit: BoxFit.cover,
    width: width,
    height: height,
  );
}
