import 'package:fbooks/app/providers.dart';
import 'package:fbooks/app/window/window_controller.dart';
import 'package:fbooks/features/reader/presentation/reader_chrome.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'fullscreen updates controls and closing the reader leaves fullscreen',
    (tester) async {
      final window = _WindowController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appWindowControllerProvider.overrideWithValue(window)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const Scaffold(
                        appBar: ReaderToolbar(
                          title: 'Reading',
                          actions: [ReaderFullscreenButton()],
                        ),
                        body: Text('Book content'),
                      ),
                    ),
                  ),
                  child: const Text('Open book'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open book'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('window-close')), findsOneWidget);

      await tester.tap(find.byTooltip('Enter full screen'));
      await tester.pumpAndSettle();
      expect(window.isFullScreen, isTrue);
      expect(find.byTooltip('Exit full screen'), findsOneWidget);
      expect(find.byKey(const Key('window-close')), findsNothing);
      expect(find.text('Book content'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(window.isFullScreen, isFalse);
      expect(window.fullScreenRequests, [true, false]);
      expect(find.text('Open book'), findsOneWidget);
      expect(find.text('Book content'), findsNothing);

      await tester.tap(find.text('Open book'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Enter full screen'));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(window.isFullScreen, isFalse);
      expect(window.fullScreenRequests, [true, false, true, false]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('does not expose a fullscreen action without window support', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: ReaderToolbar(
              title: 'Reading',
              actions: [ReaderFullscreenButton()],
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.fullscreen), findsNothing);
  });

  testWidgets('page input rejects invalid positions and follows page changes', (
    tester,
  ) async {
    int? selected;
    Widget navigation(int current) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        bottomNavigationBar: ReaderPageNavigation(
          currentPage: current,
          pageCount: 9,
          onPageSelected: (page) => selected = page,
        ),
      ),
    );
    await tester.pumpWidget(navigation(2));
    final input = find.byKey(const Key('reader-page-input'));
    for (final value in ['0', '10', '']) {
      await tester.enterText(input, value);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(selected, isNull);
      expect(tester.widget<TextField>(input).controller!.text, '2');
    }
    await tester.enterText(input, '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(selected, 7);

    await tester.pumpWidget(navigation(8));
    expect(tester.widget<TextField>(input).controller!.text, '8');
  });
}

class _WindowController extends NoopWindowController {
  final fullScreenRequests = <bool>[];
  var _fullScreen = false;

  @override
  bool get canFullScreen => true;

  @override
  bool get isFullScreen => _fullScreen;

  @override
  Future<void> setFullScreen(bool value) async {
    fullScreenRequests.add(value);
    _fullScreen = value;
    notifyListeners();
  }
}
