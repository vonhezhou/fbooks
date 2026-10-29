import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:fbooks/data/reader/archive_text_decoder.dart';
import 'package:fbooks/data/reader/legacy_codecs.dart';
import 'package:fbooks/data/reader/strict_codec.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'invalid legacy names are preserved rather than replaced or truncated',
    () {
      for (final entry in {
        ComicArchiveFileNameEncoding.big5: [0xa4],
        ComicArchiveFileNameEncoding.shiftJis: [0x82],
        ComicArchiveFileNameEncoding.eucJp: [0xa4],
        ComicArchiveFileNameEncoding.gbk: [0x90, 0x30, 0x81, 0x30],
      }.entries) {
        final name = String.fromCharCodes(entry.value);
        expect(ArchiveTextDecoder.decodeEntryName(name, entry.key), name);
      }
    },
  );

  test('legacy codecs cannot silently substitute or truncate encoded text', () {
    for (final codec in [
      gbk,
      const Big5Encoding(),
      shiftJis,
      const EucJpEncoding(),
    ]) {
      expect(
        () => encodeLosslessly(codec, 'prefix😀suffix'),
        throwsFormatException,
      );
    }
  });

  test('EUC-JP horizontal bar follows the standard mapping', () {
    expect(
      ArchiveTextDecoder.decodeEntryName(
        String.fromCharCodes([0xa1, 0xbd]),
        ComicArchiveFileNameEncoding.eucJp,
      ),
      '\u2015',
    );
  });

  test('unsupported EUC-KR is disabled without losing stored preferences', () {
    expect(ComicArchiveFileNameEncoding.eucKr.available, false);
    expect(ComicArchiveFileNameEncoding.gbk.displayName, 'GBK');
    expect(
      ComicArchiveFileNameEncodingX.fromStorageName('eucKr'),
      ComicArchiveFileNameEncoding.eucKr,
    );
    final name = String.fromCharCodes([199, 209, 177, 185]);
    expect(
      ArchiveTextDecoder.decodeEntryName(
        name,
        ComicArchiveFileNameEncoding.eucKr,
      ),
      name,
    );
  });

  test('BOMs select exact Unicode endianness and preserve supplementary characters', () {
    const fixtures = [
      [0xef, 0xbb, 0xbf, 0x41, 0xf0, 0x9f, 0x98, 0x80],
      [0xff, 0xfe, 0x41, 0, 0x3d, 0xd8, 0, 0xde],
      [0xfe, 0xff, 0, 0x41, 0xd8, 0x3d, 0xde, 0],
      [0xff, 0xfe, 0, 0, 0x41, 0, 0, 0, 0, 0xf6, 1, 0],
      [0, 0, 0xfe, 0xff, 0, 0, 0, 0x41, 0, 1, 0xf6, 0],
    ];
    for (final bytes in fixtures) {
      expect(ArchiveTextDecoder.decodeText(Uint8List.fromList(bytes)), 'A😀');
    }
  });

  test('damaged Unicode BOM data cannot fall back to a legacy encoding', () {
    const invalid = [
      [0xef, 0xbb, 0xbf, 0xff],
      [0xff, 0xfe, 0x41],
      [0xff, 0xfe, 0, 0xd8],
      [0xfe, 0xff, 0xdc, 0],
      [0xff, 0xfe, 0, 0, 1],
      [0xff, 0xfe, 0, 0, 0, 0xd8, 0, 0],
      [0, 0, 0xfe, 0xff, 0, 0x11, 0, 0],
      [0xef, 0xbb, 0xbf, 0],
    ];
    for (final bytes in invalid) {
      expect(
        ArchiveTextDecoder.decodeText(Uint8List.fromList(bytes)),
        isNull,
        reason: '$bytes',
      );
    }
  });
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
