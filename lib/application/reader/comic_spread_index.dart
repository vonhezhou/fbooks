/// Maps comic page indexes to viewer indexes when horizontal spreads are used.
class ComicSpreadIndex {
  const ComicSpreadIndex._();

  static int viewerCount({required int pageCount, required bool doublePage}) {
    if (!doublePage || pageCount <= 1) return pageCount;
    return 1 + (pageCount - 1 + 1) ~/ 2;
  }

  static int viewerIndexForPage({
    required int pageIndex,
    required bool doublePage,
  }) => !doublePage || pageIndex == 0 ? pageIndex : 1 + (pageIndex - 1) ~/ 2;

  static int firstPageForViewer({
    required int viewerIndex,
    required bool doublePage,
  }) =>
      !doublePage || viewerIndex == 0 ? viewerIndex : 1 + (viewerIndex - 1) * 2;
}
