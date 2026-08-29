import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fbooks/application/library/publication_format_inspector.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:image/image.dart' as image;
import 'package:logging/logging.dart';
import 'package:pdfrx/pdfrx.dart';

final _logger = Logger('reader.pdf_import');

abstract interface class PdfCoverRenderer {
  Future<CoverPayload?> render(Uri location);
}

/// Renders a bounded PNG preview of a PDF's first page.
class PdfrxPdfCoverRenderer implements PdfCoverRenderer {
  @override
  Future<CoverPayload?> render(Uri location) async {
    await pdfrxFlutterInitialize();
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(location.toFilePath());
      if (document.pages.isEmpty) {
        return null;
      }
      final page = document.pages.first;
      final scale = min(360 / page.width, 540 / page.height);
      final rendered = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
      );
      if (rendered == null) {
        return null;
      }
      try {
        return CoverPayload(
          fileName: 'cover.png',
          bytes: Uint8List.fromList(image.encodePng(rendered.createImageNF())),
          mediaType: 'image/png',
        );
      } finally {
        rendered.dispose();
      }
    } finally {
      await document?.dispose();
    }
  }
}

class PdfPublicationInspector implements PublicationFormatInspector {
  PdfPublicationInspector({PdfCoverRenderer? renderer})
    : _renderer = renderer ?? PdfrxPdfCoverRenderer();

  final PdfCoverRenderer _renderer;

  @override
  bool supports(PublicationFormat format) => format == PublicationFormat.pdf;

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
      return PublicationInspection(cover: await _renderer.render(location));
    } catch (error, stackTrace) {
      _logger.warning(
        'PDF import inspection failed: errorType=${error.runtimeType}.',
        null,
        stackTrace,
      );
      return null;
    }
  }
}
