import 'dart:async';

import 'package:fbooks/app/fbooks_app.dart';
import 'package:fbooks/app/logging/app_logging.dart';
import 'package:fbooks/app/logging/app_provider_observer.dart';
import 'package:fbooks/app/providers.dart';
import 'package:fbooks/app/window/window_caption.dart';
import 'package:fbooks/app/window/window_controller.dart';
import 'package:fbooks/data/preferences/shared_preferences_app_settings_repository.dart';
import 'package:fbooks/domain/settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await _initializeDesktopWindow();
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
      final AppWindowController appWindowController = isDesktopTargetPlatform
          ? DesktopWindowController()
          : NoopWindowController();
      runApp(
        ProviderScope(
          observers: const [AppProviderObserver()],
          overrides: [
            appWindowControllerProvider.overrideWithValue(appWindowController),
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

Future<void> _initializeDesktopWindow() async {
  if (!isDesktopTargetPlatform) return;
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

Future<AppSettings> _loadInitialAppSettings() async {
  try {
    return await SharedPreferencesAppSettingsRepository().load();
  } catch (_) {
    return const AppSettings();
  }
}
