enum ComicReadingMode { leftToRight, rightToLeft, vertical }

class ComicReadingPreferences {
  const ComicReadingPreferences({
    this.mode = ComicReadingMode.leftToRight,
    this.doublePage = false,
  });

  static const defaults = ComicReadingPreferences();

  final ComicReadingMode mode;
  final bool doublePage;

  bool get usesDoublePage => doublePage && mode != ComicReadingMode.vertical;

  ComicReadingPreferences copyWith({ComicReadingMode? mode, bool? doublePage}) {
    return ComicReadingPreferences(
      mode: mode ?? this.mode,
      doublePage: doublePage ?? this.doublePage,
    );
  }
}
