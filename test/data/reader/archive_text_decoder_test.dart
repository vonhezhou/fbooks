import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:fbooks/data/reader/archive_text_decoder.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves a valid UTF-8 archive entry name', () {
    const name = '第01话/001.jpg';

    expect(
      ArchiveTextDecoder.decodeEntryName(
        name,
        ComicArchiveFileNameEncoding.gbk,
      ),
      name,
    );
  });

  test('decodes a legacy GBK archive entry name', () {
    const expected = '第01话/001.jpg';
    final rawName = String.fromCharCodes(gbk.encode(expected));

    expect(
      ArchiveTextDecoder.decodeEntryName(
        rawName,
        ComicArchiveFileNameEncoding.gbk,
      ),
      expected,
    );
  });

  test('automatically normalizes detectable legacy GBK entry names', () {
    const expected = '漫画章节/第001页.jpg';
    final rawName = String.fromCharCodes(gbk.encode(expected));
    final archive = Archive()..addFile(ArchiveFile(rawName, 1, [1]));

    ArchiveTextDecoder.normalizeEntryNames(archive.files);

    expect(archive.files.single.name, expected);
  });

  test('decodes GBK ComicInfo bytes', () {
    final bytes = Uint8List.fromList(
      gbk.encode('<ComicInfo><Title>漫画</Title></ComicInfo>'),
    );

    expect(
      ArchiveTextDecoder.decodeText(bytes),
      '<ComicInfo><Title>漫画</Title></ComicInfo>',
    );
  });

  test('decodes UTF-16 ComicInfo bytes', () {
    const xml = '<ComicInfo><Title>漫画</Title></ComicInfo>';

    expect(
      ArchiveTextDecoder.decodeText(Uint8List.fromList(utf16.encode(xml))),
      xml,
    );
  });
}
