enum TextReadingAppearance { light, dark, sepia }

enum TextReadingMode { paged, scroll }

class TextReadingPreferences {
  const TextReadingPreferences({
    this.fontSize = 18,
    this.mode = TextReadingMode.paged,
    this.lineHeight = 1.7,
    this.horizontalPadding = 24,
    this.appearance = TextReadingAppearance.light,
  });

  static const defaults = TextReadingPreferences();

  final TextReadingMode mode;
  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final TextReadingAppearance appearance;

  TextReadingPreferences copyWith({
    TextReadingMode? mode,
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
    TextReadingAppearance? appearance,
  }) {
    return TextReadingPreferences(
      mode: mode ?? this.mode,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      appearance: appearance ?? this.appearance,
    );
  }
}
