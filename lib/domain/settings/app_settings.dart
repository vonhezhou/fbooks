import 'package:flutter/material.dart';

enum AppLogLevel { debug, info, warning, error }

/// Preferences that affect the application shell rather than an individual
/// reader session.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.logLevel = AppLogLevel.info,
  });

  final ThemeMode themeMode;
  final AppLogLevel logLevel;

  AppSettings copyWith({
    ThemeMode? themeMode,
    AppLogLevel? logLevel,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      logLevel: logLevel ?? this.logLevel,
    );
  }
}
