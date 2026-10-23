import 'dart:async';

import 'package:fbooks/app/providers.dart';
import 'package:fbooks/app/window/window_caption.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

class ReaderToolbar extends ConsumerWidget implements PreferredSizeWidget {
  const ReaderToolbar({
    super.key,
    required this.title,
    this.overlay = false,
    this.backgroundColor,
    this.foregroundColor,
    this.leadingActions = const [],
    this.actions = const [],
    this.progress,
    this.titleStyle,
    this.onClose,
    this.height = 64,
  });

  final String title;
  final bool overlay;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final List<Widget> leadingActions;
  final List<Widget> actions;
  final Widget? progress;
  final TextStyle? titleStyle;
  final VoidCallback? onClose;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(appWindowControllerProvider);
    final colors = Theme.of(context).colorScheme;
    final foreground =
        foregroundColor ?? (overlay ? Colors.white : colors.onSurface);
    return AnimatedBuilder(
      animation: window,
      builder: (context, _) {
        final titleText = Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              titleStyle ??
              TextStyle(
                color: foreground,
                fontSize: overlay ? 16 : 20,
                fontWeight: FontWeight.w600,
              ),
        );
        return PopScope<Object?>(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop && window.isFullScreen) {
              unawaited(window.setFullScreen(false));
            }
          },
          child: Material(
            color: overlay
                ? Colors.transparent
                : backgroundColor ?? colors.surface,
            elevation: overlay ? 0 : 1,
            shadowColor: Colors.black26,
            child: DecoratedBox(
              decoration: overlay
                  ? BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: .8),
                          Colors.transparent,
                        ],
                      ),
                    )
                  : const BoxDecoration(),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: height,
                  child: IconTheme(
                    data: IconThemeData(color: foreground, size: 24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: MaterialLocalizations.of(context)
                                .closeButtonTooltip,
                            color: foreground,
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              if (window.isFullScreen) {
                                await window.setFullScreen(false);
                              }
                              if (!context.mounted) return;
                              if (onClose != null) {
                                onClose!();
                              } else {
                                Navigator.of(context).maybePop();
                              }
                            },
                          ),
                          ...leadingActions,
                          const SizedBox(width: 8),
                          Expanded(
                            child:
                                isDesktopTargetPlatform && !window.isFullScreen
                                ? DragToMoveArea(child: titleText)
                                : titleText,
                          ),
                          if (progress != null) ...[
                            const SizedBox(width: 12),
                            progress!,
                            const SizedBox(width: 8),
                          ],
                          ...actions,
                          if (isDesktopTargetPlatform && !window.isFullScreen)
                            DesktopWindowControls(
                              brightness: overlay ? Brightness.dark : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ReaderFullscreenButton extends ConsumerWidget {
  const ReaderFullscreenButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(appWindowControllerProvider);
    if (!window.canFullScreen) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: window,
      builder: (context, _) => IconButton(
        tooltip: window.isFullScreen
            ? l10n.exitFullScreen
            : l10n.enterFullScreen,
        color: color,
        icon: Icon(
          window.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
        ),
        onPressed: () => window.setFullScreen(!window.isFullScreen),
      ),
    );
  }
}

class ReaderPageNavigation extends StatefulWidget {
  const ReaderPageNavigation({
    super.key,
    required this.currentPage,
    required this.pageCount,
    required this.onPageSelected,
    this.onPrevious,
    this.onNext,
    this.backgroundColor,
    this.foregroundColor,
  });

  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageSelected;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  State<ReaderPageNavigation> createState() => _ReaderPageNavigationState();
}

class _ReaderPageNavigationState extends State<ReaderPageNavigation> {
  late final _input = TextEditingController(text: '${widget.currentPage}');

  @override
  void didUpdateWidget(covariant ReaderPageNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      _input.text = '${widget.currentPage}';
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Material(
      color: widget.backgroundColor ?? Theme.of(context).colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Row(
                children: [
                  if (compact)
                    IconButton(
                      tooltip: l10n.previousPage,
                      onPressed: widget.onPrevious,
                      color: widget.foregroundColor,
                      icon: const Icon(Icons.chevron_left),
                    )
                  else
                    Tooltip(
                      message: l10n.previousPage,
                      child: TextButton.icon(
                        onPressed: widget.onPrevious,
                        style: TextButton.styleFrom(
                          foregroundColor: widget.foregroundColor,
                        ),
                        icon: const Icon(Icons.chevron_left),
                        label: Text(l10n.previousPage),
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      key: const Key('reader-page-input'),
                      controller: _input,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(color: widget.foregroundColor),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (value) {
                        final page = int.tryParse(value);
                        if (page != null &&
                            page >= 1 &&
                            page <= widget.pageCount) {
                          widget.onPageSelected(page);
                          FocusScope.of(context).unfocus();
                        } else {
                          _input.text = '${widget.currentPage}';
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/ ${widget.pageCount}',
                    style: TextStyle(color: widget.foregroundColor),
                  ),
                  const Spacer(),
                  if (compact)
                    IconButton(
                      tooltip: l10n.nextPage,
                      onPressed: widget.onNext,
                      color: widget.foregroundColor,
                      icon: const Icon(Icons.chevron_right),
                    )
                  else
                    Tooltip(
                      message: l10n.nextPage,
                      child: TextButton.icon(
                        onPressed: widget.onNext,
                        style: TextButton.styleFrom(
                          foregroundColor: widget.foregroundColor,
                        ),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.chevron_right),
                        label: Text(l10n.nextPage),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
