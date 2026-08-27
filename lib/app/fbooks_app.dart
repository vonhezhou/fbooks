import 'package:fbooks/features/library/presentation/library_landing_page.dart';
import 'package:flutter/material.dart';

class FbooksApp extends StatelessWidget {
  const FbooksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fbooks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B5BDB),
          brightness: Brightness.light,
          surface: const Color(0xFFF8F7F3),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F7F3),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F7F3),
          foregroundColor: Color(0xFF1C1D20),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        useMaterial3: true,
      ),
      home: const LibraryLandingPage(),
    );
  }
}
