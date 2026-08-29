import 'package:fbooks/domain/settings/app_settings.dart';
import 'package:fbooks/domain/settings/app_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesAppSettingsRepository implements AppSettingsRepository {
  static const _themeModeKey = 'app.theme-mode';
  static const _localeKey = 'app.locale';
  static const _logLevelKey = 'app.log-level';

  @override
  Future<AppSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_themeModeKey);
    final themeMode = ThemeMode.values
        .where((mode) => mode.name == stored)
        .firstOrNull;
    final localeCode = preferences.getString(_localeKey);
    final storedLogLevel = preferences.getString(_logLevelKey);
    final logLevel = AppLogLevel.values
        .where((level) => level.name == storedLogLevel)
        .firstOrNull;
    return AppSettings(
      themeMode: themeMode ?? ThemeMode.system,
      locale: localeCode == null ? null : Locale(localeCode),
      logLevel: logLevel ?? AppLogLevel.info,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, settings.themeMode.name);
    if (settings.locale == null) {
      await preferences.remove(_localeKey);
    } else {
      await preferences.setString(_localeKey, settings.locale!.languageCode);
    }
    await preferences.setString(_logLevelKey, settings.logLevel.name);
  }
}
