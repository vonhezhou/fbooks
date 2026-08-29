import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/reading/flow_document.dart';

abstract interface class FlowReadingSession {
  FlowDocument get document;

  /// Loads a chapter only when the reader needs to display it.
  ///
  /// EPUB sessions use this boundary to defer XHTML parsing and resource
  /// extraction; plain text sessions return their already-loaded chapter.
  Future<FlowChapter> loadChapter(int index);

  /// Releases reader resources held outside the UI isolate.
  Future<void> close();
}

abstract interface class FlowReadingSessionFactory {
  Future<FlowReadingSession> open(Publication publication);
}
