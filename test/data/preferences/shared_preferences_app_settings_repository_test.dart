import 'package:fbooks/data/preferences/shared_preferences_app_settings_repository.dart';
import 'package:fbooks/domain/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesAppSettingsRepository', () {
    test('defaults the log level to info for existing installations', () async {
      SharedPreferences.setMockInitialValues({'app.theme-mode': 'dark'});

      final settings = await SharedPreferencesAppSettingsRepository().load();

      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.logLevel, AppLogLevel.info);
    });

    test('persists the selected log level with other app settings', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SharedPreferencesAppSettingsRepository();
      const settings = AppSettings(
        themeMode: ThemeMode.light,
        logLevel: AppLogLevel.warning,
      );

      await repository.save(settings);
      final restored = await repository.load();

      expect(restored.themeMode, ThemeMode.light);
      expect(restored.logLevel, AppLogLevel.warning);
    });
  });
}
