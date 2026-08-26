import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('comic locators retain a zero-based page index', () {
    const locator = ComicPageLocator(18);

    expect(locator.pageIndex, 18);
  });

  test('text locators retain a chapter and character offset', () {
    const locator = TextOffsetLocator(chapterIndex: 2, offset: 640);

    expect(locator.chapterIndex, 2);
    expect(locator.offset, 640);
  });
}
