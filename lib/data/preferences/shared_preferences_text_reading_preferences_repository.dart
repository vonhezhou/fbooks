import 'package:fbooks/domain/reading/text_reading_preferences.dart';
import 'package:fbooks/domain/reading/text_reading_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesTextReadingPreferencesRepository
    implements TextReadingPreferencesRepository {
  static const _modeKey = 'text-reading-mode';
  static const _fontSizeKey = 'text-reading-font-size';
  static const _lineHeightKey = 'text-reading-line-height';
  static const _horizontalPaddingKey = 'text-reading-horizontal-padding';
  static const _appearanceKey = 'text-reading-appearance';

  @override
  Future<TextReadingPreferences> load() async {
    final storage = await SharedPreferences.getInstance();
    final appearanceName = storage.getString(_appearanceKey);
    return TextReadingPreferences(
      mode: TextReadingMode.values.firstWhere(
        (mode) => mode.name == storage.getString(_modeKey),
        orElse: () => TextReadingMode.paged,
      ),
      fontSize: storage.getDouble(_fontSizeKey) ?? 18,
      lineHeight: storage.getDouble(_lineHeightKey) ?? 1.7,
      horizontalPadding: storage.getDouble(_horizontalPaddingKey) ?? 24,
      appearance: TextReadingAppearance.values.firstWhere(
        (appearance) => appearance.name == appearanceName,
        orElse: () => TextReadingAppearance.light,
      ),
    );
  }

  @override
  Future<void> save(TextReadingPreferences preferences) async {
    final storage = await SharedPreferences.getInstance();
    await storage.setString(_modeKey, preferences.mode.name);
    await storage.setDouble(_fontSizeKey, preferences.fontSize);
    await storage.setDouble(_lineHeightKey, preferences.lineHeight);
    await storage.setDouble(
      _horizontalPaddingKey,
      preferences.horizontalPadding,
    );
    await storage.setString(_appearanceKey, preferences.appearance.name);
  }
}
