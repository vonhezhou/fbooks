import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Describes the desktop window operations exposed to the Flutter UI.
abstract interface class AppWindowController implements Listenable {
  bool get isMaximized;
  bool get canFullScreen;
  bool get isFullScreen;

  Future<void> minimize();

  Future<void> toggleMaximize();

  Future<void> close();

  Future<void> setFullScreen(bool value);
}

/// Safe default for targets without a native desktop window.
class NoopWindowController extends ChangeNotifier
    implements AppWindowController {
  @override
  bool get isMaximized => false;

  @override
  bool get canFullScreen => false;

  @override
  bool get isFullScreen => false;

  @override
  Future<void> setFullScreen(bool value) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> minimize() async {}

  @override
  Future<void> toggleMaximize() async {}
}

/// Bridges the application window to [windowManager].
class DesktopWindowController extends ChangeNotifier
    with WindowListener
    implements AppWindowController {
  DesktopWindowController({WindowManager? manager})
    : _manager = manager ?? windowManager {
    _manager.addListener(this);
    unawaited(_refreshMaximized());
    unawaited(_refreshFullScreen());
  }

  final WindowManager _manager;
  var _isMaximized = false;
  var _isFullScreen = false;

  @override
  bool get isMaximized => _isMaximized;

  @override
  bool get canFullScreen => true;

  @override
  bool get isFullScreen => _isFullScreen;

  @override
  Future<void> setFullScreen(bool value) async {
    await _manager.setFullScreen(value);
    await _refreshFullScreen();
  }

  @override
  Future<void> minimize() => _manager.minimize();

  @override
  Future<void> toggleMaximize() async {
    if (_isMaximized) {
      await _manager.unmaximize();
    } else {
      await _manager.maximize();
    }
    await _refreshMaximized();
  }

  @override
  Future<void> close() => _manager.close();

  @override
  void onWindowMaximize() => _setMaximized(true);

  @override
  void onWindowUnmaximize() => _setMaximized(false);

  @override
  void onWindowEnterFullScreen() => _setFullScreen(true);

  @override
  void onWindowLeaveFullScreen() => _setFullScreen(false);

  Future<void> _refreshFullScreen() async {
    _setFullScreen(await _manager.isFullScreen());
  }

  void _setFullScreen(bool value) {
    if (_isFullScreen == value) return;
    _isFullScreen = value;
    notifyListeners();
  }

  Future<void> _refreshMaximized() async {
    _setMaximized(await _manager.isMaximized());
  }

  void _setMaximized(bool value) {
    if (_isMaximized == value) return;
    _isMaximized = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _manager.removeListener(this);
    super.dispose();
  }
}
