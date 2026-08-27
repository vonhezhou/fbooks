enum TextReadingAppearance { light, dark, sepia }

class TextReadingPreferences {
  const TextReadingPreferences({
    this.fontSize = 18,
    this.lineHeight = 1.7,
    this.horizontalPadding = 24,
    this.appearance = TextReadingAppearance.light,
  });

  static const defaults = TextReadingPreferences();

  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final TextReadingAppearance appearance;

  TextReadingPreferences copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
    TextReadingAppearance? appearance,
  }) {
    return TextReadingPreferences(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      appearance: appearance ?? this.appearance,
    );
  }
}
