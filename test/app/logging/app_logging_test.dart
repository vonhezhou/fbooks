import 'dart:io';

import 'package:fbooks/app/logging/app_logging.dart';
import 'package:fbooks/app/logging/app_provider_observer.dart';
import 'package:fbooks/app/providers.dart';
import 'package:fbooks/domain/settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

void main() {
  group('app logging', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp('fbooks-log-');
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('writes local diagnostics with the startup session header', () async {
      final handle = await initializeAppLogging(
        appVersion: '1.2.3+4',
        directoryResolver: () async => temporaryDirectory,
        isReleaseMode: true,
      );
      addTearDown(handle!.dispose);

      Logger('test.diagnostics').warning('A recoverable test failure.');
      await handle.dispose();

      final file = File(path.join(temporaryDirectory.path, appLogFileName));
      final contents = await file.readAsString();
      expect(contents, contains('Session started: version=1.2.3+4'));
      expect(contents, contains('A recoverable test failure.'));
    });

    test(
      'logs Riverpod provider failures without provider arguments',
      () async {
        final handle = await initializeAppLogging(
          appVersion: 'test',
          directoryResolver: () async => temporaryDirectory,
          isReleaseMode: true,
        );
        final container = ProviderContainer(
          observers: const [AppProviderObserver()],
        );
        addTearDown(container.dispose);
        addTearDown(handle!.dispose);
        final failingProvider = Provider<Object>(
          (ref) => throw StateError('bad'),
        );

        expect(() => container.read(failingProvider), throwsA(anything));
        await handle.dispose();

        final file = File(path.join(temporaryDirectory.path, appLogFileName));
        expect(await file.readAsString(), contains('Provider failed:'));
      },
    );

    test('exposes the initialized log directory through an override', () {
      final container = ProviderContainer(
        overrides: [
          appLogDirectoryProvider.overrideWithValue('/diagnostics/fbooks/logs'),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(appLogDirectoryProvider),
        '/diagnostics/fbooks/logs',
      );
    });

    test('continues when a local log directory cannot be resolved', () async {
      final handle = await initializeAppLogging(
        appVersion: 'test',
        directoryResolver: () => throw const FileSystemException('unavailable'),
        isReleaseMode: true,
      );

      expect(handle, isNull);
    });

    test('updates the root logger to the selected app log level', () async {
      await initializeAppLogging(
        appVersion: 'test',
        directoryResolver: () async => temporaryDirectory,
        isReleaseMode: true,
      );

      applyAppLogLevel(AppLogLevel.warning);
      expect(Logger.root.level, Level.WARNING);

      applyAppLogLevel(AppLogLevel.debug);
      expect(Logger.root.level, Level.ALL);
    });
  });
}
