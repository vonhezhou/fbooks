import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fbooks/data/reader/local_text_reader_session.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opens an EPUB spine as ordered text chapters', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fbooks-epub-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/sample.epub');

    final archive = Archive()
      ..addFile(
        _textArchiveFile(
          'META-INF/container.xml',
          '''<?xml version="1.0"?>
            <container><rootfiles><rootfile full-path="OEBPS/book.opf" /></rootfiles></container>''',
        ),
      )
      ..addFile(
        _textArchiveFile('OEBPS/book.opf', '''<package><manifest>
              <item id="first" href="first.xhtml" />
              <item id="second" href="second.xhtml" />
            </manifest><spine>
              <itemref idref="first" />
              <itemref idref="second" />
            </spine></package>'''),
      )
      ..addFile(
        _textArchiveFile(
          'OEBPS/first.xhtml',
          '<html><body><h1>First</h1><p>Hello <em>world</em>.</p><p>Second paragraph.</p></body></html>',
        ),
      )
      ..addFile(
        _textArchiveFile(
          'OEBPS/second.xhtml',
          '<html><body><h1>Second</h1><p>Goodbye world.</p></body></html>',
        ),
      );
    await file.writeAsBytes(ZipEncoder().encode(archive));

    final session = await LocalTextReaderSessionFactory().open(
      _publication(id: 'epub', file: file, format: PublicationFormat.epub),
    );

    expect(session.document.chapters.map((chapter) => chapter.title), [
      'First',
      'Second',
    ]);
    final first = session.document.chapters.first;
    expect(first.text, 'Hello world.\n\nSecond paragraph.');
    expect(
      first.segments.where((segment) => segment.emphasized).single.text,
      'world',
    );
  });

  test('opens a local text file as one chapter', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fbooks-text-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/notes.txt');
    await file.writeAsString('A plain-text chapter.');

    final session = await LocalTextReaderSessionFactory().open(
      _publication(id: 'text', file: file, format: PublicationFormat.text),
    );

    expect(session.document.chapters.single.title, 'notes');
    expect(session.document.chapters.single.text, 'A plain-text chapter.');
  });
}

ArchiveFile _textArchiveFile(String name, String text) {
  final bytes = utf8.encode(text);
  return ArchiveFile(name, bytes.length, bytes);
}

Publication _publication({
  required String id,
  required File file,
  required PublicationFormat format,
}) {
  return Publication(
    id: id,
    source: const LibrarySource(
      id: 'local-library',
      kind: LibrarySourceKind.local,
      name: 'Local library',
    ),
    title: id,
    format: format,
    assets: [
      PublicationAsset(
        id: '$id-file',
        publicationId: id,
        kind: PublicationAssetKind.localFile,
        location: Uri.file(file.path),
      ),
    ],
  );
}
