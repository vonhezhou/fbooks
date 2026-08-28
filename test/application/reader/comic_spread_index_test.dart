import 'package:fbooks/application/reader/comic_spread_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the cover single and pairs subsequent pages', () {
    expect(ComicSpreadIndex.viewerCount(pageCount: 5, doublePage: true), 3);
    expect(
      [
        for (var page = 0; page < 5; page++)
          ComicSpreadIndex.viewerIndexForPage(
            pageIndex: page,
            doublePage: true,
          ),
      ],
      [0, 1, 1, 2, 2],
    );
    expect(
      [
        for (var viewer = 0; viewer < 3; viewer++)
          ComicSpreadIndex.firstPageForViewer(
            viewerIndex: viewer,
            doublePage: true,
          ),
      ],
      [0, 1, 3],
    );
  });

  test('uses one viewer per page when spreads are disabled', () {
    expect(ComicSpreadIndex.viewerCount(pageCount: 3, doublePage: false), 3);
    expect(
      ComicSpreadIndex.viewerIndexForPage(pageIndex: 2, doublePage: false),
      2,
    );
  });
}
