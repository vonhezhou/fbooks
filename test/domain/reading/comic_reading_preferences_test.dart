import 'package:fbooks/domain/reading/comic_reading_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('double-page spreads are disabled for vertical reading', () {
    const preferences = ComicReadingPreferences(
      mode: ComicReadingMode.vertical,
      doublePage: true,
    );

    expect(preferences.usesDoublePage, isFalse);
  });

  test('horizontal modes can use double-page spreads', () {
    const preferences = ComicReadingPreferences(doublePage: true);

    expect(preferences.usesDoublePage, isTrue);
  });
}
