import 'dart:io';
import 'dart:typed_data';

import 'package:fbooks/data/reader/text_publication_inspector.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('creates a deterministic PNG cover for a text publication', () async {
    final directory = await Directory.systemTemp.createTemp('fbooks-text-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/notes.txt');
    await file.writeAsString('Plain text');
    final inspector = TextPublicationInspector();

    final first = await inspector.inspect(
      format: PublicationFormat.text,
      location: file.uri,
    );
    final second = await inspector.inspect(
      format: PublicationFormat.text,
      location: file.uri,
    );
    final decoded = image.decodePng(first?.cover?.bytes ?? Uint8List(0));

    expect(first?.cover?.fileName, 'text-cover.png');
    expect(first?.cover?.mediaType, 'image/png');
    expect(decoded?.width, 360);
    expect(decoded?.height, 540);
    expect(second?.cover?.bytes, first?.cover?.bytes);
  });
}
