import 'package:fbooks/data/preferences/shared_preferences_text_reading_preferences_repository.dart';
import 'package:fbooks/domain/reading/text_reading_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'defaults missing and unknown reading modes to horizontal pages',
    () async {
      for (final values in [
        <String, Object>{},
        <String, Object>{'text-reading-mode': 'unknown'},
      ]) {
        SharedPreferences.setMockInitialValues(values);
        expect(
          (await SharedPreferencesTextReadingPreferencesRepository().load())
              .mode,
          TextReadingMode.paged,
        );
      }
    },
  );

  test('persists text reading preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesTextReadingPreferencesRepository();
    const preferences = TextReadingPreferences(
      fontSize: 22,
      mode: TextReadingMode.scroll,
      lineHeight: 1.9,
      horizontalPadding: 40,
      appearance: TextReadingAppearance.sepia,
    );

    await repository.save(preferences);

    final restored = await repository.load();
    expect(restored.fontSize, 22);
    expect(restored.mode, TextReadingMode.scroll);
    expect(restored.lineHeight, 1.9);
    expect(restored.horizontalPadding, 40);
    expect(restored.appearance, TextReadingAppearance.sepia);
  });
}
