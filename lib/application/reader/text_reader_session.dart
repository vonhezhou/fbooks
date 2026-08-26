import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/reading/text_document.dart';

abstract interface class TextReaderSession {
  TextDocument get document;
}

abstract interface class TextReaderSessionFactory {
  Future<TextReaderSession> open(Publication publication);
}
