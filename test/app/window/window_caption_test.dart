import 'package:fbooks/app/providers.dart';
import 'package:fbooks/app/window/window_caption.dart';
import 'package:fbooks/app/window/window_controller.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders and delegates desktop window controls', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final controller = _FakeWindowController();

    await tester.pumpWidget(
      _CaptionTestApp(
        controller: controller,
        caption: const DesktopWindowCaption(),
      ),
    );

    expect(find.byKey(const Key('window-minimize')), findsOneWidget);
    expect(find.byKey(const Key('window-maximize')), findsOneWidget);
    expect(find.byKey(const Key('window-close')), findsOneWidget);
    expect(find.bySemanticsLabel('Close window'), findsOneWidget);

    await tester.tap(find.byKey(const Key('window-minimize')));
    await tester.tap(find.byKey(const Key('window-maximize')));
    await tester.tap(find.byKey(const Key('window-close')));
    await tester.pump();

    expect(controller.minimizeCalls, 1);
    expect(controller.maximizeToggleCalls, 1);
    expect(controller.closeCalls, 1);
    expect(find.byKey(const Key('window-restore')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('adds window controls to a desktop content app bar', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    await tester.pumpWidget(
      _CaptionTestApp(
        controller: _FakeWindowController(),
        caption: fbooksAppBar(title: const Text('Page title')),
      ),
    );

    expect(find.text('Page title'), findsOneWidget);
    expect(find.byKey(const Key('window-minimize')), findsOneWidget);
    expect(find.byKey(const Key('window-maximize')), findsOneWidget);
    expect(find.byKey(const Key('window-close')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('keeps the standard app bar on mobile', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await tester.pumpWidget(
      _CaptionTestApp(
        controller: _FakeWindowController(),
        caption: fbooksAppBar(title: const Text('Page title')),
      ),
    );

    expect(find.text('Page title'), findsOneWidget);
    expect(find.byKey(const Key('window-minimize')), findsNothing);
    expect(find.byKey(const Key('window-maximize')), findsNothing);
    expect(find.byKey(const Key('window-close')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}

class _CaptionTestApp extends StatelessWidget {
  const _CaptionTestApp({required this.controller, required this.caption});

  final AppWindowController controller;
  final PreferredSizeWidget caption;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [appWindowControllerProvider.overrideWithValue(controller)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(appBar: caption),
    ),
  );
}

class _FakeWindowController extends ChangeNotifier
    implements AppWindowController {
  @override
  bool get canFullScreen => false;

  @override
  bool get isFullScreen => false;

  @override
  Future<void> setFullScreen(bool value) async {}

  @override
  bool isMaximized = false;

  var minimizeCalls = 0;
  var maximizeToggleCalls = 0;
  var closeCalls = 0;

  @override
  Future<void> close() async {
    closeCalls++;
  }

  @override
  Future<void> minimize() async {
    minimizeCalls++;
  }

  @override
  Future<void> toggleMaximize() async {
    maximizeToggleCalls++;
    isMaximized = !isMaximized;
    notifyListeners();
  }
}
