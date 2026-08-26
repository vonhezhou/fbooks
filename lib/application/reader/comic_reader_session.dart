import 'dart:typed_data';

import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/reading/comic_document.dart';

abstract interface class ComicReaderSession {
  ComicDocument get document;

  Future<Uint8List> readPage(int pageIndex);
}

abstract interface class ComicReaderSessionFactory {
  Future<ComicReaderSession> open(Publication publication);
}
