import 'package:fbooks/domain/reading/reading_locator.dart';

class StoredReadingLocator {
  const StoredReadingLocator({required this.type, required this.value});

  final String type;
  final String value;
}

class ReadingLocatorCodec {
  const ReadingLocatorCodec._();

  static StoredReadingLocator encode(ReadingLocator locator) {
    return switch (locator) {
      ComicPageLocator(:final pageIndex) => StoredReadingLocator(
        type: 'comic-page',
        value: '$pageIndex',
      ),
      EpubCfiLocator(:final cfi) => StoredReadingLocator(
        type: 'epub-cfi',
        value: cfi,
      ),
      PdfPageLocator(:final pageNumber) => StoredReadingLocator(
        type: 'pdf-page',
        value: '$pageNumber',
      ),
      TextOffsetLocator(
        :final chapterIndex,
        :final offset,
        :final paragraphIndex,
        :final characterOffset,
      ) =>
        StoredReadingLocator(
          type: 'text-offset',
          value: paragraphIndex == null
              ? '$chapterIndex:$offset'
              : '$chapterIndex:$offset:$paragraphIndex:$characterOffset',
        ),
    };
  }

  static ReadingLocator decode({required String type, required String value}) {
    return switch (type) {
      'comic-page' => ComicPageLocator(int.parse(value)),
      'epub-cfi' => EpubCfiLocator(value),
      'pdf-page' => PdfPageLocator(int.parse(value)),
      'text-offset' => _decodeTextOffset(value),
      _ => throw FormatException('Unknown reading locator type: $type'),
    };
  }

  static TextOffsetLocator _decodeTextOffset(String value) {
    final pieces = value.split(':');
    if (pieces.length != 2 && pieces.length != 4) {
      throw FormatException('Invalid text offset locator: $value');
    }

    return TextOffsetLocator(
      chapterIndex: int.parse(pieces[0]),
      offset: int.parse(pieces[1]),
      paragraphIndex: pieces.length == 4 ? int.parse(pieces[2]) : null,
      characterOffset: pieces.length == 4 ? int.parse(pieces[3]) : null,
    );
  }
}
