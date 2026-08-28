import 'package:fbooks/data/persistence/reading_locator_codec.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips a comic page locator', () {
    const original = ComicPageLocator(18);

    final stored = ReadingLocatorCodec.encode(original);
    final restored = ReadingLocatorCodec.decode(
      type: stored.type,
      value: stored.value,
    );

    expect(restored, isA<ComicPageLocator>());
    expect((restored as ComicPageLocator).pageIndex, 18);
  });

  test('round-trips a text offset locator', () {
    const original = TextOffsetLocator(chapterIndex: 2, offset: 640);

    final stored = ReadingLocatorCodec.encode(original);
    final restored = ReadingLocatorCodec.decode(
      type: stored.type,
      value: stored.value,
    );

    expect(restored, isA<TextOffsetLocator>());
    final textLocator = restored as TextOffsetLocator;
    expect(textLocator.chapterIndex, 2);
    expect(textLocator.offset, 640);
  });

  test('round-trips a PDF page locator', () {
    const original = PdfPageLocator(12);

    final stored = ReadingLocatorCodec.encode(original);
    final restored = ReadingLocatorCodec.decode(
      type: stored.type,
      value: stored.value,
    );

    expect(restored, isA<PdfPageLocator>());
    expect((restored as PdfPageLocator).pageNumber, 12);
  });
}
