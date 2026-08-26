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
      TextOffsetLocator(:final chapterIndex, :final offset) =>
        StoredReadingLocator(
          type: 'text-offset',
          value: '$chapterIndex:$offset',
        ),
    };
  }

  static ReadingLocator decode({required String type, required String value}) {
    return switch (type) {
      'comic-page' => ComicPageLocator(int.parse(value)),
      'epub-cfi' => EpubCfiLocator(value),
      'text-offset' => _decodeTextOffset(value),
      _ => throw FormatException('Unknown reading locator type: $type'),
    };
  }

  static TextOffsetLocator _decodeTextOffset(String value) {
    final pieces = value.split(':');
    if (pieces.length != 2) {
      throw FormatException('Invalid text offset locator: $value');
    }

    return TextOffsetLocator(
      chapterIndex: int.parse(pieces[0]),
      offset: int.parse(pieces[1]),
    );
  }
}
