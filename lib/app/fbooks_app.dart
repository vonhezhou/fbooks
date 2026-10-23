import 'package:fbooks/app/providers.dart';
import 'package:fbooks/app/logging/app_logging.dart';
import 'package:fbooks/features/library/presentation/library_landing_page.dart';
import 'package:fbooks/features/navigation/presentation/not_found_page.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FbooksApp extends ConsumerWidget {
  const FbooksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(appSettingsProvider, (_, next) {
      final settings = next.asData?.value;
      if (settings != null) {
        applyAppLogLevel(settings.logLevel);
      }
    });
    final themeMode =
        ref.watch(appSettingsProvider).asData?.value.themeMode ??
        ThemeMode.system;
    final locale = ref.watch(appSettingsProvider).asData?.value.locale;
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LibraryLandingPage(),
      onUnknownRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => NotFoundPage(routeName: settings.name),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFFD0BCFF) : const Color(0xFF6750A4),
        onPrimary: dark ? const Color(0xFF381E72) : Colors.white,
        primaryContainer: dark
            ? const Color(0xFF4F378B)
            : const Color(0xFFEADDFF),
        onPrimaryContainer: dark
            ? const Color(0xFFEADDFF)
            : const Color(0xFF21005D),
        surface: dark ? const Color(0xFF1C1B1F) : const Color(0xFFFFFBFE),
        onSurface: dark ? const Color(0xFFE6E1E5) : const Color(0xFF1C1B1F),
        onSurfaceVariant: dark
            ? const Color(0xFFCAC4D0)
            : const Color(0xFF49454F),
        outline: dark ? const Color(0xFF938F99) : const Color(0xFF79747E),
        outlineVariant: dark
            ? const Color(0xFF49454F)
            : const Color(0xFFCAC4D0),
      );
  final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: colorScheme.outlineVariant),
  );
  return base.copyWith(
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 24,
        height: 1.334,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 24,
        height: 1.334,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 20,
        height: 1.6,
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: .42)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 40),
      suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.onSurface.withValues(alpha: 0.12),
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearMinHeight: 4,
      color: colorScheme.primary,
      linearTrackColor: dark
          ? colorScheme.primaryContainer
          : const Color(0xFFC5BCDC),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: const CircleBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 56,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: selected ? 14 : 12,
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
