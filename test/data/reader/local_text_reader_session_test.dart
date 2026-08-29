import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fbooks/data/reader/local_text_reader_session.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opens an EPUB spine parsed in a background isolate', () async {
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
            <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/book.opf" /></rootfiles></container>''',
        ),
      )
      ..addFile(
        _textArchiveFile('OEBPS/book.opf', '''<package xmlns="http://www.idpf.org/2007/opf" version="2.0"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Sample</dc:title></metadata><manifest>
              <item id="first" href="first.xhtml" media-type="application/xhtml+xml" />
              <item id="second" href="second.xhtml" media-type="application/xhtml+xml" />
              <item id="pixel" href="images/pixel.gif" media-type="image/gif" />
              <item id="nav" href="nav.ncx" media-type="application/x-dtbncx+xml" />
            </manifest><spine toc="nav">
              <itemref idref="first" />
              <itemref idref="second" />
            </spine></package>'''),
      )
      ..addFile(
        _textArchiveFile(
          'OEBPS/nav.ncx',
          '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/"><head></head><docTitle><text>Sample</text></docTitle><navMap><navPoint id="first" playOrder="1"><navLabel><text>Beginning</text></navLabel><content src="first.xhtml" /></navPoint><navPoint id="second" playOrder="2"><navLabel><text>Ending</text></navLabel><content src="second.xhtml" /></navPoint></navMap></ncx>',
        ),
      )
      ..addFile(
        _textArchiveFile(
          'OEBPS/first.xhtml',
          '<html><body><h1>First</h1><p>Hello <em>world</em>.</p><p><img src="images/pixel.gif" alt="A pixel" /></p><table><tr><th>Year</th><th>Sales</th></tr><tr><td>2025</td><td>42</td></tr></table><p><a href="second.xhtml#afterword">Read the next chapter</a></p><p>Second paragraph.</p></body></html>',
        ),
      )
      ..addFile(
        ArchiveFile('OEBPS/images/pixel.gif', _pixelGif.length, _pixelGif),
      )
      ..addFile(
        _textArchiveFile(
          'OEBPS/second.xhtml',
          '<html><body><h1>Second</h1><p id="afterword">Goodbye world.</p></body></html>',
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
    expect(
      first.text,
      'Hello world.\n\nRead the next chapter\n\nSecond paragraph.',
    );
    expect(
      first.segments.where((segment) => segment.emphasized).single.text,
      'world',
    );
    final linkSegment = first.segments.singleWhere(
      (segment) => segment.linkTargetChapterIndex != null,
    );
    expect(linkSegment.text, 'Read the next chapter');
    expect(linkSegment.linkTargetChapterIndex, 1);
    final imageSegment = first.segments.singleWhere(
      (segment) => segment.isImage,
    );
    expect(imageSegment.imageMimeType, 'image/gif');
    expect(imageSegment.imageBytes, _pixelGif);
    expect(
      first.segments.singleWhere((segment) => segment.isTable).table?.rows,
      [
        ['Year', 'Sales'],
        ['2025', '42'],
      ],
    );
    expect(session.document.tableOfContents.map((entry) => entry.title), [
      'Beginning',
      'Ending',
    ]);
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

final _pixelGif = base64Decode(
  'R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==',
);

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
