import 'package:flutter/material.dart';

/// Presents reading controls as a desktop side panel or a compact mobile sheet.
Future<void> showReaderSettingsSurface(
  BuildContext context, {
  required bool desktop,
  required Key desktopKey,
  required Widget child,
  Alignment desktopAlignment = Alignment.centerRight,
  Offset desktopEntryOffset = const Offset(1, 0),
  String barrierLabel = 'Dismiss reading panel',
  double desktopWidth = 360,
}) {
  if (!desktop) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: child,
      ),
    );
  }

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black54,
    pageBuilder: (context, animation, secondaryAnimation) => Align(
      alignment: desktopAlignment,
      child: SizedBox(
        key: desktopKey,
        width: desktopWidth.clamp(0, MediaQuery.sizeOf(context).width),
        height: MediaQuery.sizeOf(context).height,
        child: child,
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        SlideTransition(
          position: Tween<Offset>(
            begin: desktopEntryOffset,
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
  );
}
