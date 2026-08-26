import 'package:fbooks/domain/library/library_source.dart';

abstract interface class LibrarySourceRepository {
  Future<List<LibrarySource>> listSources();

  Future<void> save(LibrarySource source);

  Future<void> delete(String sourceId);
}
