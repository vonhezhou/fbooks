/// Estimates a scroll offset for a page in a lazily built, continuous comic
/// reader. The exact page extent is only known after images load, so callers
/// refine this position with [Scrollable.ensureVisible] when possible.
abstract final class VerticalComicPagePosition {
  static double estimateOffset({
    required int pageIndex,
    required int pageCount,
    required double maxScrollExtent,
  }) {
    if (pageCount <= 1 || maxScrollExtent <= 0) {
      return 0;
    }
    final clampedPage = pageIndex.clamp(0, pageCount - 1);
    return maxScrollExtent * clampedPage / (pageCount - 1);
  }
}
