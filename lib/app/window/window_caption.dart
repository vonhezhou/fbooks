import 'package:fbooks/app/providers.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

bool get isDesktopTargetPlatform =>
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows;

/// A draggable desktop caption that matches the surrounding app surface.
class DesktopWindowCaption extends StatelessWidget
    implements PreferredSizeWidget {
  const DesktopWindowCaption({super.key, this.height = 40});

  final double height;

  @override
  Size get preferredSize =>
      Size.fromHeight(isDesktopTargetPlatform ? height : 0);

  @override
  Widget build(BuildContext context) {
    if (!isDesktopTargetPlatform) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
      child: Row(
        children: [
          const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
          const DesktopWindowControls(),
        ],
      ),
    );
  }
}

/// The shared Flutter-rendered desktop window controls.
class DesktopWindowControls extends ConsumerWidget {
  const DesktopWindowControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDesktopTargetPlatform) return const SizedBox.shrink();
    final controller = ref.watch(appWindowControllerProvider);
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => LimitedBox(
        maxHeight: 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Tooltip(
              message: l10n.minimizeWindow,
              child: Semantics(
                label: l10n.minimizeWindow,
                button: true,
                child: WindowCaptionButton.minimize(
                  key: const Key('window-minimize'),
                  brightness: brightness,
                  onPressed: () => controller.minimize(),
                ),
              ),
            ),
            Tooltip(
              message: controller.isMaximized
                  ? l10n.restoreWindow
                  : l10n.maximizeWindow,
              child: Semantics(
                label: controller.isMaximized
                    ? l10n.restoreWindow
                    : l10n.maximizeWindow,
                button: true,
                child: controller.isMaximized
                    ? WindowCaptionButton.unmaximize(
                        key: const Key('window-restore'),
                        brightness: brightness,
                        onPressed: () => controller.toggleMaximize(),
                      )
                    : WindowCaptionButton.maximize(
                        key: const Key('window-maximize'),
                        brightness: brightness,
                        onPressed: () => controller.toggleMaximize(),
                      ),
              ),
            ),
            Tooltip(
              message: l10n.closeWindow,
              child: Semantics(
                label: l10n.closeWindow,
                button: true,
                child: WindowCaptionButton.close(
                  key: const Key('window-close'),
                  brightness: brightness,
                  onPressed: () => controller.close(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Returns an [AppBar] that doubles as a draggable desktop window caption.
AppBar fbooksAppBar({
  Widget? title,
  List<Widget> actions = const [],
  double? toolbarHeight,
  Color? backgroundColor,
  Color? foregroundColor,
  Color? surfaceTintColor,
  bool? centerTitle,
}) {
  final desktop = isDesktopTargetPlatform;
  return AppBar(
    toolbarHeight: desktop ? (toolbarHeight ?? 48) : toolbarHeight,
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    surfaceTintColor: surfaceTintColor,
    centerTitle: centerTitle,
    title: desktop && title != null ? DragToMoveArea(child: title) : title,
    flexibleSpace: desktop
        ? const DragToMoveArea(child: SizedBox.expand())
        : null,
    actions: [...actions, if (desktop) const DesktopWindowControls()],
  );
}
