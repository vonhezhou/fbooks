import 'dart:io';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/data/reader/archive_comic_publication_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses ComicInfo FrontCover before filename cover heuristics', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fbooks-comicinfo-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/sample.cbz');
    const xml = '''<ComicInfo>
      <Title>漫画标题</Title>
      <Writer>作者</Writer>
      <Summary>漫画简介</Summary>
      <Year>2024</Year>
      <Month>5</Month>
      <Day>6</Day>
      <Genre>Action, Drama</Genre>
      <Pages><Page Image="2" Type="FrontCover" /></Pages>
    </ComicInfo>''';
    final bytes = gbk.encode(xml);
    final archive = Archive()
      ..addFile(ArchiveFile('ComicInfo.xml', bytes.length, bytes))
      ..addFile(ArchiveFile('001.jpg', 1, [1]))
      ..addFile(ArchiveFile('front-cover.png', 2, [2, 3]))
      ..addFile(ArchiveFile('z9.jpg', 1, [9]));
    await file.writeAsBytes(ZipEncoder().encode(archive));

    final importData = await ArchiveComicPublicationInspector().inspect(
      format: PublicationFormat.comicArchive,
      location: file.uri,
    );

    expect(importData?.metadata?.title, '漫画标题');
    expect(importData?.metadata?.authors, ['作者']);
    expect(importData?.metadata?.description, '漫画简介');
    expect(importData?.metadata?.publishedAt, DateTime(2024, 5, 6));
    expect(importData?.metadata?.tags, ['Action', 'Drama']);
    expect(importData?.cover?.fileName, 'z9.jpg');
    expect(importData?.cover?.bytes, [9]);
  });

  test(
    'uses the first naturally ordered page when no cover is named',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'fbooks-comicinfo-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/sample.cbz');
      final archive = Archive()
        ..addFile(ArchiveFile('chapter/10.jpg', 1, [10]))
        ..addFile(ArchiveFile('chapter/2.jpg', 1, [2]));
      await file.writeAsBytes(ZipEncoder().encode(archive));

      final importData = await ArchiveComicPublicationInspector().inspect(
        format: PublicationFormat.comicArchive,
        location: file.uri,
      );

      expect(importData?.metadata, isNull);
      expect(importData?.cover?.fileName, 'chapter/2.jpg');
      expect(importData?.cover?.bytes, [2]);
    },
  );
}
