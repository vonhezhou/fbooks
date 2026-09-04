/// The stable, format-aware content length shown outside the reader.
///
/// Reflowable publications do not have a fixed page count because it changes
/// with the reading appearance and available width, so they report chapters.
class PublicationContentInfo {
  const PublicationContentInfo.pages(this.total)
    : assert(total >= 0),
      unit = PublicationContentUnit.page;

  const PublicationContentInfo.chapters(this.total)
    : assert(total >= 0),
      unit = PublicationContentUnit.chapter;

  final int total;
  final PublicationContentUnit unit;
}

enum PublicationContentUnit { page, chapter }
