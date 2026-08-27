import 'package:fbooks/application/reader/vertical_comic_page_position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('estimates a proportional vertical offset for an in-range page', () {
    expect(
      VerticalComicPagePosition.estimateOffset(
        pageIndex: 3,
        pageCount: 5,
        maxScrollExtent: 1200,
      ),
      900,
    );
  });

  test('clamps a requested page and handles a one-page comic', () {
    expect(
      VerticalComicPagePosition.estimateOffset(
        pageIndex: 20,
        pageCount: 5,
        maxScrollExtent: 1200,
      ),
      1200,
    );
    expect(
      VerticalComicPagePosition.estimateOffset(
        pageIndex: 0,
        pageCount: 1,
        maxScrollExtent: 1200,
      ),
      0,
    );
  });
}
