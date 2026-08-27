import 'package:fbooks/domain/reading/comic_reading_preferences.dart';

abstract interface class ComicReadingPreferencesRepository {
  Future<ComicReadingPreferences> load();

  Future<void> save(ComicReadingPreferences preferences);
}
