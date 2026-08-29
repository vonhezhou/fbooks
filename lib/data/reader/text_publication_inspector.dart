import 'dart:io';
import 'dart:typed_data';

import 'package:fbooks/application/library/publication_format_inspector.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:image/image.dart' as image;
import 'package:logging/logging.dart';

final _logger = Logger('reader.text_import');

/// Creates a small deterministic cover for plain-text publications.
class TextPublicationInspector implements PublicationFormatInspector {
  @override
  bool supports(PublicationFormat format) => format == PublicationFormat.text;

  @override
  Future<PublicationInspection?> inspect({
    required PublicationFormat format,
    required Uri location,
  }) async {
    if (!supports(format) || location.scheme != 'file') {
      return null;
    }
    if (!await File.fromUri(location).exists()) {
      return null;
    }
    try {
      return PublicationInspection(cover: _coverFor(location));
    } catch (error, stackTrace) {
      _logger.warning(
        'Text import inspection failed: errorType=${error.runtimeType}.',
        null,
        stackTrace,
      );
      return null;
    }
  }

  CoverPayload _coverFor(Uri location) {
    final palette = _palettes[_stableHash(location.path) % _palettes.length];
    final canvas = image.Image(width: 360, height: 540, numChannels: 4);
    image.fill(
      canvas,
      color: image.ColorRgba8(palette.$1, palette.$2, palette.$3, 255),
    );
    image.fillRect(
      canvas,
      x1: 32,
      y1: 34,
      x2: 328,
      y2: 506,
      color: image.ColorRgba8(255, 255, 255, 32),
      radius: 20,
    );
    image.fillRect(
      canvas,
      x1: 72,
      y1: 246,
      x2: 288,
      y2: 250,
      color: image.ColorRgba8(255, 255, 255, 160),
    );
    image.drawString(
      canvas,
      'TXT',
      font: image.arial48,
      color: image.ColorRgba8(255, 255, 255, 255),
    );
    return CoverPayload(
      fileName: 'text-cover.png',
      bytes: Uint8List.fromList(image.encodePng(canvas)),
      mediaType: 'image/png',
    );
  }

  int _stableHash(String value) {
    var hash = 17;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash;
  }
}

const _palettes = <(int, int, int)>[
  (36, 79, 128),
  (106, 64, 132),
  (38, 116, 102),
  (155, 93, 48),
];
