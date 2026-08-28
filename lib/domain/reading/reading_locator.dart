/// A format-aware, stable place in a publication.
///
/// UI page indices are intentionally not used as a universal position: comics,
/// EPUBs and plain text each need their own durable locator.
sealed class ReadingLocator {
  const ReadingLocator();
}

class ComicPageLocator extends ReadingLocator {
  const ComicPageLocator(this.pageIndex) : assert(pageIndex >= 0);

  final int pageIndex;
}

class EpubCfiLocator extends ReadingLocator {
  const EpubCfiLocator(this.cfi) : assert(cfi.length > 0);

  final String cfi;
}

class PdfPageLocator extends ReadingLocator {
  const PdfPageLocator(this.pageNumber) : assert(pageNumber >= 1);

  final int pageNumber;
}

class TextOffsetLocator extends ReadingLocator {
  const TextOffsetLocator({required this.chapterIndex, required this.offset})
    : assert(chapterIndex >= 0),
      assert(offset >= 0);

  final int chapterIndex;
  final int offset;
}
