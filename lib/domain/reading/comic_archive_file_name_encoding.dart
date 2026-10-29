enum ComicArchiveFileNameEncoding {
  auto,
  gbk,
  big5,
  shiftJis,
  eucJp,
  eucKr,
  cp437,
  cp737,
  windows1250,
  windows1251,
  windows1252,
  windows1253,
  windows1254,
  windows1255,
  windows1256,
  windows1257,
  windows1258,
}

extension ComicArchiveFileNameEncodingX on ComicArchiveFileNameEncoding {
  bool get available => this != ComicArchiveFileNameEncoding.eucKr;
  String? get storageName => switch (this) {
    ComicArchiveFileNameEncoding.auto => null,
    _ => name,
  };

  String get displayName => switch (this) {
    ComicArchiveFileNameEncoding.auto => 'Automatic',
    ComicArchiveFileNameEncoding.gbk => 'GBK',
    ComicArchiveFileNameEncoding.big5 => 'Big5',
    ComicArchiveFileNameEncoding.shiftJis => 'Shift_JIS',
    ComicArchiveFileNameEncoding.eucJp => 'EUC-JP',
    ComicArchiveFileNameEncoding.eucKr => 'EUC-KR (unavailable)',
    ComicArchiveFileNameEncoding.cp437 => 'CP437 (DOS)',
    ComicArchiveFileNameEncoding.cp737 => 'CP737 (Greek)',
    ComicArchiveFileNameEncoding.windows1250 => 'Windows-1250',
    ComicArchiveFileNameEncoding.windows1251 => 'Windows-1251',
    ComicArchiveFileNameEncoding.windows1252 => 'Windows-1252',
    ComicArchiveFileNameEncoding.windows1253 => 'Windows-1253',
    ComicArchiveFileNameEncoding.windows1254 => 'Windows-1254',
    ComicArchiveFileNameEncoding.windows1255 => 'Windows-1255',
    ComicArchiveFileNameEncoding.windows1256 => 'Windows-1256',
    ComicArchiveFileNameEncoding.windows1257 => 'Windows-1257',
    ComicArchiveFileNameEncoding.windows1258 => 'Windows-1258',
  };

  static ComicArchiveFileNameEncoding fromStorageName(String? value) {
    return ComicArchiveFileNameEncoding.values.firstWhere(
      (encoding) => encoding.storageName == value,
      orElse: () => ComicArchiveFileNameEncoding.auto,
    );
  }
}
