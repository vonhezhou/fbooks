import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fbooks/data/reader/epub_publication_inspector.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'uses an EPUB3 cover-image manifest item and embedded metadata',
    () async {
      final directory = await Directory.systemTemp.createTemp('fbooks-epub-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/sample.epub');
      final archive = Archive()
        ..addFile(ArchiveFile('mimetype', 20, 'application/epub+zip'.codeUnits))
        ..addFile(
          ArchiveFile(
            'META-INF/container.xml',
            _containerXml.length,
            _containerXml.codeUnits,
          ),
        )
        ..addFile(
          ArchiveFile(
            'OEBPS/content.opf',
            _packageDocument.length,
            _packageDocument.codeUnits,
          ),
        )
        ..addFile(
          ArchiveFile(
            'OEBPS/nav.xhtml',
            _navigation.length,
            _navigation.codeUnits,
          ),
        )
        ..addFile(
          ArchiveFile('OEBPS/text.xhtml', _chapter.length, _chapter.codeUnits),
        )
        ..addFile(ArchiveFile('OEBPS/images/front.png', 3, [1, 2, 3]));
      await file.writeAsBytes(ZipEncoder().encode(archive));

      final result = await EpubPublicationInspector().inspect(
        format: PublicationFormat.epub,
        location: file.uri,
      );

      expect(result?.metadata?.title, 'Embedded EPUB title');
      expect(result?.metadata?.authors, ['Author']);
      expect(result?.metadata?.publishedAt, DateTime(2024, 5, 6));
      expect(result?.metadata?.tags, ['Fiction', 'Gardens']);
      expect(result?.cover?.fileName, 'front.png');
      expect(result?.cover?.bytes, [1, 2, 3]);
      expect(result?.cover?.mediaType, 'image/png');
    },
  );
}

const _containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml" />
  </rootfiles>
</container>''';

const _packageDocument = '''<?xml version="1.0" encoding="utf-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Embedded EPUB title</dc:title>
    <dc:creator>Author</dc:creator>
    <dc:date>2024-05-06</dc:date>
    <dc:subject>Fiction</dc:subject>
    <dc:subject>Gardens</dc:subject>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav" />
    <item id="chapter" href="text.xhtml" media-type="application/xhtml+xml" />
    <item id="cover" href="images/front.png" media-type="image/png" properties="cover-image" />
  </manifest>
  <spine><itemref idref="chapter" /></spine>
</package>''';

const _navigation = '''<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Contents</title></head>
  <body><nav><ol><li><a href="text.xhtml">Chapter</a></li></ol></nav></body>
</html>''';

const _chapter = '''<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Chapter</title></head><body><p>Text</p></body>
</html>''';
