import 'package:flutter/material.dart';

class LibraryLandingPage extends StatelessWidget {
  const LibraryLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fbooks')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories_outlined, size: 64),
              SizedBox(height: 16),
              Text(
                'Your library will appear here.',
                style: TextStyle(fontSize: 20),
              ),
              SizedBox(height: 8),
              Text(
                'Start by importing a local publication or connecting an OPDS source.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
