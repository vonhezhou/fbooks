import 'package:flutter/material.dart';

enum AppLogLevel { debug, info, warning, error }

/// Preferences that affect the application shell rather than an individual
/// reader session.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.logLevel = AppLogLevel.info,
  });

  final ThemeMode themeMode;
  final Locale? locale;
  final AppLogLevel logLevel;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    AppLogLevel? logLevel,
    bool clearLocale = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: clearLocale ? null : locale ?? this.locale,
      logLevel: logLevel ?? this.logLevel,
    );
  }
}
