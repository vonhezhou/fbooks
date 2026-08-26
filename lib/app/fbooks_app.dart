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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LibraryLandingPage(),
    );
  }
}
