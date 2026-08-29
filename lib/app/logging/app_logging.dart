import 'dart:io';

import 'package:fbooks/domain/settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const appLogFileName = 'fbooks.log';
const appLogRotateAtSizeBytes = 10 * 1024 * 1024;
const appLogKeepRotateCount = 3;

final _lifecycleLogger = Logger('app.lifecycle');
final _errorLogger = Logger('app.errors');

/// Owns the local file logger created during application startup.
class AppLogHandle {
  AppLogHandle._({required this.directory, required this.fileAppender});

  final Directory directory;
  final RotatingFileAppender fileAppender;

  Future<void> dispose() => fileAppender.dispose();
}

/// Configures local diagnostics without allowing a logging failure to stop boot.
Future<AppLogHandle?> initializeAppLogging({
  required String appVersion,
  Future<Directory> Function()? directoryResolver,
  bool? isReleaseMode,
  AppLogLevel? logLevel,
}) async {
  final releaseMode = isReleaseMode ?? kReleaseMode;
  final configuredLogLevel =
      logLevel ?? (releaseMode ? AppLogLevel.info : AppLogLevel.debug);
  Logger.root
    ..clearListeners()
    ..level = _loggingLevelFor(configuredLogLevel);

  if (!releaseMode) {
    PrintAppender(formatter: const ColorFormatter())
        .attachToLogger(Logger.root);
  }

  try {
    final directory = await (directoryResolver ?? _defaultLogDirectory)();
    await directory.create(recursive: true);
    final fileAppender = RotatingFileAppender(
      baseFilePath: path.join(directory.path, appLogFileName),
      keepRotateCount: appLogKeepRotateCount,
      rotateAtSizeBytes: appLogRotateAtSizeBytes,
    );
    fileAppender.attachToLogger(Logger.root);
    final handle = AppLogHandle._(
      directory: directory,
      fileAppender: fileAppender,
    );
    _lifecycleLogger.log(
      _loggingLevelFor(configuredLogLevel),
      'Session started: version=$appVersion, '
      'mode=${releaseMode ? 'release' : 'debug'}, '
      'logLevel=${configuredLogLevel.name}, '
      'os=${Platform.operatingSystem}, dart=${Platform.version}.',
    );
    return handle;
  } catch (error, stackTrace) {
    if (!releaseMode) {
      debugPrint(
        'Unable to initialize local logging: '
        'errorType=${error.runtimeType}.\n$stackTrace',
      );
    }
    return null;
  }
}

void applyAppLogLevel(AppLogLevel logLevel) {
  final loggingLevel = _loggingLevelFor(logLevel);
  Logger.root.level = loggingLevel;
  _lifecycleLogger.log(loggingLevel, 'Log level changed: ${logLevel.name}.');
}

Level _loggingLevelFor(AppLogLevel logLevel) => switch (logLevel) {
  AppLogLevel.debug => Level.ALL,
  AppLogLevel.info => Level.INFO,
  AppLogLevel.warning => Level.WARNING,
  AppLogLevel.error => Level.SEVERE,
};

Future<Directory> _defaultLogDirectory() async {
  final applicationSupportDirectory = await getApplicationSupportDirectory();
  return Directory(
    path.join(applicationSupportDirectory.path, 'fbooks', 'logs'),
  );
}

void reportUnhandledError(String message, Object error, StackTrace stackTrace) {
  _errorLogger.severe(
    '$message errorType=${error.runtimeType}.',
    null,
    stackTrace,
  );
}
