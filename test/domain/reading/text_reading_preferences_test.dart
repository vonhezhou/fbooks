import 'package:fbooks/domain/reading/text_reading_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text reading preferences retain unspecified values when copied', () {
    const preferences = TextReadingPreferences(
      fontSize: 20,
      lineHeight: 1.9,
      horizontalPadding: 36,
      appearance: TextReadingAppearance.sepia,
    );

    final updated = preferences.copyWith(fontSize: 22);

    expect(updated.fontSize, 22);
    expect(updated.lineHeight, 1.9);
    expect(updated.horizontalPadding, 36);
    expect(updated.appearance, TextReadingAppearance.sepia);
  });
}
