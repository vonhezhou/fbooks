import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Shown when a named navigation request does not match the application.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.routeName});

  final String? routeName;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 64),
            const SizedBox(height: 18),
            Text(
              AppLocalizations.of(context).notFoundTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              routeName == null || routeName!.isEmpty
                  ? AppLocalizations.of(context).notFoundDescription
                  : AppLocalizations.of(context)
                        .notFoundRouteDescription(routeName!),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              icon: const Icon(Icons.home_outlined),
              label: Text(AppLocalizations.of(context).backToLibrary),
            ),
          ],
        ),
      ),
    ),
  );
}
