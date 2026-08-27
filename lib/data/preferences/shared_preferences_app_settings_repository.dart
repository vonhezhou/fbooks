import 'package:fbooks/domain/settings/app_settings.dart';
import 'package:fbooks/domain/settings/app_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesAppSettingsRepository implements AppSettingsRepository {
  static const _themeModeKey = 'app.theme-mode';

  @override
  Future<AppSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_themeModeKey);
    final themeMode = ThemeMode.values
        .where((mode) => mode.name == stored)
        .firstOrNull;
    return AppSettings(themeMode: themeMode ?? ThemeMode.system);
  }

  @override
  Future<void> save(AppSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, settings.themeMode.name);
  }
}
