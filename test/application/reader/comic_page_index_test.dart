import 'package:fbooks/application/reader/comic_page_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters non-images and applies natural page ordering', () {
    final pages = ComicPageIndex.fromEntryNames([
      'chapter/10.jpg',
      'chapter/2.jpg',
      'chapter/1.jpg',
      'ComicInfo.xml',
      '__MACOSX/metadata',
    ]);

    expect(pages.map((page) => page.name), [
      'chapter/1.jpg',
      'chapter/2.jpg',
      'chapter/10.jpg',
    ]);
  });
}
