import 'package:fbooks/domain/reading/text_reading_preferences.dart';

abstract interface class TextReadingPreferencesRepository {
  Future<TextReadingPreferences> load();

  Future<void> save(TextReadingPreferences preferences);
}
