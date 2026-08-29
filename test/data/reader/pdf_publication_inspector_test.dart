import 'dart:io';
import 'dart:typed_data';

import 'package:fbooks/application/library/publication_format_inspector.dart';
import 'package:fbooks/data/reader/pdf_publication_inspector.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores the first-page preview supplied by the PDF renderer', () async {
    final directory = await Directory.systemTemp.createTemp('fbooks-pdf-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/sample.pdf');
    await file.writeAsBytes([37, 80, 68, 70]);
    final renderer = _RecordingPdfCoverRenderer();

    final result = await PdfPublicationInspector(renderer: renderer)
        .inspect(format: PublicationFormat.pdf, location: file.uri);

    expect(renderer.location, file.uri);
    expect(result?.cover?.mediaType, 'image/png');
    expect(result?.cover?.bytes, [1, 2, 3]);
  });

  test('does not fail inspection when rendering the preview fails', () async {
    final directory = await Directory.systemTemp.createTemp('fbooks-pdf-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/sample.pdf');
    await file.writeAsBytes([37, 80, 68, 70]);

    final result = await PdfPublicationInspector(
      renderer: _FailingPdfCoverRenderer(),
    ).inspect(format: PublicationFormat.pdf, location: file.uri);

    expect(result, isNull);
  });
}

class _RecordingPdfCoverRenderer implements PdfCoverRenderer {
  Uri? location;

  @override
  Future<CoverPayload?> render(Uri value) async {
    location = value;
    return CoverPayload(
      fileName: 'cover.png',
      bytes: Uint8List.fromList([1, 2, 3]),
      mediaType: 'image/png',
    );
  }
}

class _FailingPdfCoverRenderer implements PdfCoverRenderer {
  @override
  Future<CoverPayload?> render(Uri location) =>
      Future.error(StateError('Rendering failed'));
}
