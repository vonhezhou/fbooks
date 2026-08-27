import 'package:fbooks/domain/reading/comic_reading_preferences.dart';
import 'package:fbooks/domain/reading/comic_reading_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesComicReadingPreferencesRepository
    implements ComicReadingPreferencesRepository {
  static const _modeKey = 'comic-reading-mode';
  static const _doublePageKey = 'comic-double-page';

  @override
  Future<ComicReadingPreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    final modeName = preferences.getString(_modeKey);
    return ComicReadingPreferences(
      mode: ComicReadingMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => ComicReadingMode.leftToRight,
      ),
      doublePage: preferences.getBool(_doublePageKey) ?? false,
    );
  }

  @override
  Future<void> save(ComicReadingPreferences preferences) async {
    final storage = await SharedPreferences.getInstance();
    await storage.setString(_modeKey, preferences.mode.name);
    await storage.setBool(_doublePageKey, preferences.doublePage);
  }
}
