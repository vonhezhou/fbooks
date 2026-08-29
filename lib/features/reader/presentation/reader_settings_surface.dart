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
}) {
  if (!desktop) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => child,
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
        width: 420,
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
