import 'dart:async';
import 'dart:ui';

import 'package:fbooks/app/fbooks_app.dart';
import 'package:fbooks/app/logging/app_logging.dart';
import 'package:fbooks/app/logging/app_provider_observer.dart';
import 'package:fbooks/app/providers.dart';
import 'package:fbooks/data/preferences/shared_preferences_app_settings_repository.dart';
import 'package:fbooks/domain/settings/app_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final appSettings = await _loadInitialAppSettings();
      final logHandle = await initializeAppLogging(
        appVersion: const String.fromEnvironment(
          'FBOOKS_APP_VERSION',
          defaultValue: 'unknown',
        ),
        logLevel: appSettings.logLevel,
      );
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        reportUnhandledError(
          'Flutter framework error.',
          details.exception,
          details.stack ?? StackTrace.empty,
        );
      };
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        reportUnhandledError('Platform dispatcher error.', error, stackTrace);
        return true;
      };
      pdfrxFlutterInitialize();
      runApp(
        ProviderScope(
          observers: const [AppProviderObserver()],
          overrides: [
            appLogDirectoryProvider.overrideWithValue(
              logHandle?.directory.path,
            ),
          ],
          child: const FbooksApp(),
        ),
      );
    },
    (error, stackTrace) =>
        reportUnhandledError('Unhandled zone error.', error, stackTrace),
  );
}

Future<AppSettings> _loadInitialAppSettings() async {
  try {
    return await SharedPreferencesAppSettingsRepository().load();
  } catch (_) {
    return const AppSettings();
  }
}
