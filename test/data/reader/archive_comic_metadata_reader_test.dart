import 'dart:io';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:fbooks/data/reader/archive_comic_metadata_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads GBK ComicInfo metadata from a CBZ', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fbooks-comicinfo-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/sample.cbz');
    const xml = '''<ComicInfo>
      <Title>漫画标题</Title>
      <Writer>作者</Writer>
      <Summary>漫画简介</Summary>
    </ComicInfo>''';
    final bytes = gbk.encode(xml);
    final archive = Archive()
      ..addFile(ArchiveFile('ComicInfo.xml', bytes.length, bytes))
      ..addFile(ArchiveFile('001.jpg', 1, [1]));
    await file.writeAsBytes(ZipEncoder().encode(archive));

    final metadata = await ArchiveComicMetadataReader().read(file.uri);

    expect(metadata?.title, '漫画标题');
    expect(metadata?.author, '作者');
    expect(metadata?.description, '漫画简介');
  });

  test('returns null when ComicInfo is absent', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fbooks-comicinfo-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/sample.cbz');
    final archive = Archive()..addFile(ArchiveFile('001.jpg', 1, [1]));
    await file.writeAsBytes(ZipEncoder().encode(archive));

    expect(await ArchiveComicMetadataReader().read(file.uri), isNull);
  });
}
