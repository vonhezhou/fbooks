import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding.dart';
import 'package:fbooks/data/reader/legacy_codecs.dart';
import 'package:fbooks/data/reader/strict_codec.dart';
import 'package:uchardet/uchardet.dart' as uchardet;

class ArchiveTextDecoder {
  const ArchiveTextDecoder._();

  static ComicArchiveFileNameEncoding? detectEntryNameEncoding(
    Iterable<String> names,
  ) {
    final bytes = <int>[];
    for (final name in names) {
      if (!_hasSingleByteNonAscii(name)) {
        continue;
      }
      bytes
        ..addAll(_rawBytes(name))
        ..add(0);
    }
    return bytes.isEmpty ? null : _detect(Uint8List.fromList(bytes));
  }

  static void normalizeEntryNames(
    Iterable<ArchiveFile> entries, {
    ComicArchiveFileNameEncoding? override,
  }) {
    final selected =
        override ?? detectEntryNameEncoding(entries.map((entry) => entry.name));
    if (selected == null || selected == ComicArchiveFileNameEncoding.auto) {
      return;
    }
    for (final entry in entries) {
      entry.name = decodeEntryName(entry.name, selected);
    }
  }

  static String decodeEntryName(
    String name,
    ComicArchiveFileNameEncoding encoding,
  ) {
    if (!_hasSingleByteNonAscii(name)) {
      return name;
    }
    try {
      return decodeLosslessly(_codecFor(encoding), _rawBytes(name));
    } on FormatException {
      return name;
    }
  }

  static String? decodeText(Uint8List bytes) {
    // BOM 是确定证据，损坏的 Unicode 不能再被猜成旧编码而掩盖错误。
    final bom = _bomEncoding(bytes);
    if (bom != null) {
      try {
        return _decodeUnicode(bytes, bom);
      } on FormatException {
        return null;
      }
    }
    try {
      final text = utf8.decode(bytes);
      if (!text.contains('\x00')) return text;
    } on FormatException {
      // ComicInfo defaults to UTF-8, so only use guessing for invalid UTF-8.
    }
    final unicodeEncoding = _unicodeTextEncoding(bytes);
    if (unicodeEncoding != null) {
      try {
        return _decodeUnicode(bytes, unicodeEncoding);
      } on FormatException {
        // The detector can report UTF-8 for short legacy text; continue with
        // the legacy-code-page fallback below.
      }
    }
    final encoding = _detect(bytes);
    if (encoding != null) {
      try {
        final text = decodeLosslessly(_codecFor(encoding), bytes);
        return text.contains('\x00') ? null : text;
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  static bool _hasSingleByteNonAscii(String value) =>
      value.codeUnits.any((unit) => unit >= 0x80 && unit <= 0xff) &&
      value.codeUnits.every((unit) => unit <= 0xff);

  static Uint8List _rawBytes(String value) =>
      Uint8List.fromList(value.codeUnits.map((unit) => unit & 0xff).toList());

  static uchardet.Encoding? _unicodeTextEncoding(Uint8List bytes) {
    final candidate = uchardet.UCharDet().detect(bytes).firstOrNull;
    return switch (candidate?.encoding) {
      uchardet.Encoding.ascii ||
      uchardet.Encoding.utf8 ||
      uchardet.Encoding.utf16le ||
      uchardet.Encoding.utf16be ||
      uchardet.Encoding.utf32le ||
      uchardet.Encoding.utf32be => candidate!.encoding,
      _ => null,
    };
  }

  static uchardet.Encoding? _bomEncoding(List<int> bytes) {
    bool starts(List<int> prefix) =>
        bytes.length >= prefix.length &&
        List.generate(
          prefix.length,
          (i) => bytes[i] == prefix[i],
        ).every((v) => v);
    if (starts([0xff, 0xfe, 0, 0])) return uchardet.Encoding.utf32le;
    if (starts([0, 0, 0xfe, 0xff])) return uchardet.Encoding.utf32be;
    if (starts([0xef, 0xbb, 0xbf])) return uchardet.Encoding.utf8;
    if (starts([0xff, 0xfe])) return uchardet.Encoding.utf16le;
    if (starts([0xfe, 0xff])) return uchardet.Encoding.utf16be;
    return null;
  }

  static String _decodeUnicode(List<int> bytes, uchardet.Encoding encoding) {
    final hasBom = _bomEncoding(bytes) == encoding;
    if (encoding == uchardet.Encoding.utf8 ||
        encoding == uchardet.Encoding.ascii) {
      final text = utf8.decode(bytes.sublist(hasBom ? 3 : 0));
      if (text.contains('\x00')) throw const FormatException('文本包含空字符');
      return text;
    }
    final utf32 =
        encoding == uchardet.Encoding.utf32le ||
        encoding == uchardet.Encoding.utf32be;
    final little =
        encoding == uchardet.Encoding.utf16le ||
        encoding == uchardet.Encoding.utf32le;
    final size = utf32 ? 4 : 2, skip = hasBom ? (utf32 ? 4 : 2) : 0;
    if ((bytes.length - skip) % size != 0) {
      throw const FormatException('Unicode 字节不完整');
    }
    final units = <int>[];
    for (var i = skip; i < bytes.length; i += size) {
      var unit = 0;
      for (var j = 0; j < size; j++) {
        unit |= bytes[i + j] << (8 * (little ? j : size - 1 - j));
      }
      if (utf32 && (unit > 0x10ffff || unit >= 0xd800 && unit <= 0xdfff)) {
        throw const FormatException('Unicode 码点无效');
      }
      units.add(unit);
    }
    if (!utf32) {
      for (var i = 0; i < units.length; i++) {
        if (units[i] >= 0xd800 && units[i] <= 0xdbff) {
          if (++i >= units.length || units[i] < 0xdc00 || units[i] > 0xdfff) {
            throw const FormatException('UTF-16 代理对无效');
          }
        } else if (units[i] >= 0xdc00 && units[i] <= 0xdfff) {
          throw const FormatException('UTF-16 代理对无效');
        }
      }
    }
    final text = String.fromCharCodes(units);
    if (text.contains('\x00')) throw const FormatException('文本包含空字符');
    return text;
  }

  static ComicArchiveFileNameEncoding? _detect(Uint8List bytes) {
    final candidate = uchardet.UCharDet().detect(bytes).firstOrNull;
    final detected = switch (candidate?.encoding) {
      uchardet.Encoding.gb18030 => ComicArchiveFileNameEncoding.gbk,
      uchardet.Encoding.big5 => ComicArchiveFileNameEncoding.big5,
      uchardet.Encoding.shiftJIS => ComicArchiveFileNameEncoding.shiftJis,
      uchardet.Encoding.eucJP => ComicArchiveFileNameEncoding.eucJp,
      uchardet.Encoding.eucKR => ComicArchiveFileNameEncoding.eucKr,
      _ => null,
    };
    if (detected != null) {
      return detected;
    }

    // UCharDet often classifies a short GBK file name as a Western single-byte
    // encoding. Charset's strict GBK compatibility check is a better fallback
    // for the Windows comic archives this reader targets.
    if (Charset.detect(bytes) == gbk) {
      return ComicArchiveFileNameEncoding.gbk;
    }

    return switch (candidate?.encoding) {
      uchardet.Encoding.windows1250 => ComicArchiveFileNameEncoding.windows1250,
      uchardet.Encoding.windows1251 => ComicArchiveFileNameEncoding.windows1251,
      uchardet.Encoding.windows1252 => ComicArchiveFileNameEncoding.windows1252,
      uchardet.Encoding.windows1253 => ComicArchiveFileNameEncoding.windows1253,
      uchardet.Encoding.windows1255 => ComicArchiveFileNameEncoding.windows1255,
      uchardet.Encoding.windows1256 => ComicArchiveFileNameEncoding.windows1256,
      uchardet.Encoding.windows1257 => ComicArchiveFileNameEncoding.windows1257,
      uchardet.Encoding.windows1258 => ComicArchiveFileNameEncoding.windows1258,
      uchardet.Encoding.cp737 => ComicArchiveFileNameEncoding.cp737,
      _ => null,
    };
  }

  static Encoding _codecFor(ComicArchiveFileNameEncoding encoding) {
    return switch (encoding) {
      ComicArchiveFileNameEncoding.auto => utf8,
      ComicArchiveFileNameEncoding.gbk => gbk,
      ComicArchiveFileNameEncoding.big5 => const Big5Encoding(),
      ComicArchiveFileNameEncoding.shiftJis => shiftJis,
      ComicArchiveFileNameEncoding.eucJp => const EucJpEncoding(),
      // charset 2.0.1 的 EUC-KR 表方向错误，往返一致也可能解出错误文字。
      ComicArchiveFileNameEncoding.eucKr => throw const FormatException(
        'EUC-KR 暂不可用',
      ),
      ComicArchiveFileNameEncoding.cp437 => cp437,
      ComicArchiveFileNameEncoding.cp737 => cp737,
      ComicArchiveFileNameEncoding.windows1250 => windows1250,
      ComicArchiveFileNameEncoding.windows1251 => windows1251,
      ComicArchiveFileNameEncoding.windows1252 => windows1252,
      ComicArchiveFileNameEncoding.windows1253 => windows1253,
      ComicArchiveFileNameEncoding.windows1254 => windows1254,
      ComicArchiveFileNameEncoding.windows1255 => windows1255,
      ComicArchiveFileNameEncoding.windows1256 => windows1256,
      ComicArchiveFileNameEncoding.windows1257 => windows1257,
      ComicArchiveFileNameEncoding.windows1258 => windows1258,
    };
  }
}
