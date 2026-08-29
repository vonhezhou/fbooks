import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:dart_big5/big5.dart' as big5;
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding.dart';
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
      return _codecFor(encoding).decode(_rawBytes(name));
    } on FormatException {
      return name;
    }
  }

  static String? decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      // ComicInfo defaults to UTF-8, so only use guessing for invalid UTF-8.
    }
    final unicodeEncoding = _unicodeTextEncoding(bytes);
    if (unicodeEncoding != null) {
      try {
        return unicodeEncoding.decode(bytes);
      } on FormatException {
        // The detector can report UTF-8 for short legacy text; continue with
        // the legacy-code-page fallback below.
      }
    }
    final encoding = _detect(bytes);
    if (encoding != null) {
      try {
        return _codecFor(encoding).decode(bytes);
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

  static Encoding? _unicodeTextEncoding(Uint8List bytes) {
    final candidate = uchardet.UCharDet().detect(bytes).firstOrNull;
    return switch (candidate?.encoding) {
      uchardet.Encoding.ascii || uchardet.Encoding.utf8 => utf8,
      uchardet.Encoding.utf16le || uchardet.Encoding.utf16be => utf16,
      uchardet.Encoding.utf32le || uchardet.Encoding.utf32be => utf32,
      _ => null,
    };
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
      ComicArchiveFileNameEncoding.big5 => const _Big5Codec(),
      ComicArchiveFileNameEncoding.shiftJis => shiftJis,
      ComicArchiveFileNameEncoding.eucJp => eucJp,
      ComicArchiveFileNameEncoding.eucKr => eucKr,
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

class _Big5Codec extends Encoding {
  const _Big5Codec();

  @override
  Converter<List<int>, String> get decoder => const _Big5Decoder();

  @override
  Converter<String, List<int>> get encoder => const _Big5Encoder();

  @override
  String get name => 'big5';
}

class _Big5Decoder extends Converter<List<int>, String> {
  const _Big5Decoder();

  @override
  String convert(List<int> input) => big5.Big5TransformDecode(input);
}

class _Big5Encoder extends Converter<String, List<int>> {
  const _Big5Encoder();

  @override
  List<int> convert(String input) => big5.Big5TransformEncode(input);
}
