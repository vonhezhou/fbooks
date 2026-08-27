import 'package:flutter/material.dart';

/// Preferences that affect the application shell rather than an individual
/// reader session.
class AppSettings {
  const AppSettings({this.themeMode = ThemeMode.system});

  final ThemeMode themeMode;
}
