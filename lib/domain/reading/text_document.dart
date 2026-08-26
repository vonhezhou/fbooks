import 'package:fbooks/domain/publication/publication_id.dart';

/// Extracted, reflowable text shared by the reader, TTS, and AI features.
class TextDocument {
  const TextDocument({required this.publicationId, required this.chapters});

  final PublicationId publicationId;
  final List<TextChapter> chapters;
}

class TextChapter {
  const TextChapter({
    required this.index,
    required this.title,
    required this.text,
  });

  final int index;
  final String title;
  final String text;
}
