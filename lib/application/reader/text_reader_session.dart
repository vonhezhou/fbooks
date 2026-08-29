import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/reading/text_document.dart';

abstract interface class TextReaderSession {
  TextDocument get document;

  /// Loads a chapter only when the reader needs to display it.
  ///
  /// EPUB sessions use this boundary to defer XHTML parsing and resource
  /// extraction; plain text sessions return their already-loaded chapter.
  Future<TextChapter> loadChapter(int index);

  /// Releases reader resources held outside the UI isolate.
  Future<void> close();
}

abstract interface class TextReaderSessionFactory {
  Future<TextReaderSession> open(Publication publication);
}
