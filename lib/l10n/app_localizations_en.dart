// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'fBooks';

  @override
  String get library => 'Library';

  @override
  String get collections => 'Collections';

  @override
  String get plugins => 'Plugins';

  @override
  String get settings => 'Settings';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get minimizeWindow => 'Minimize window';

  @override
  String get maximizeWindow => 'Maximize window';

  @override
  String get restoreWindow => 'Restore window';

  @override
  String get closeWindow => 'Close window';

  @override
  String get retry => 'Retry';

  @override
  String get remove => 'Remove';

  @override
  String get add => 'Add';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get previous => 'Previous';

  @override
  String get done => 'Done';

  @override
  String get noItems => 'No items yet';

  @override
  String unableToLoad(String error) {
    return 'Unable to load: $error';
  }

  @override
  String booksCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books',
      one: '1 book',
      zero: 'No books',
    );
    return '$_temp0';
  }

  @override
  String collectionsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count custom collections',
      one: '1 custom collection',
      zero: 'No custom collections',
    );
    return '$_temp0';
  }

  @override
  String get language => 'Language';

  @override
  String get languageDescription =>
      'Follow your device language or choose an app language.';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => 'Chinese (Simplified)';

  @override
  String get appearance => 'Appearance';

  @override
  String get colorMode => 'Color mode';

  @override
  String get colorModeDescription =>
      'Follow the system or choose a permanent reading environment.';

  @override
  String get about => 'About';

  @override
  String get reading => 'Reading';

  @override
  String get localLibrary => 'Local library';

  @override
  String get comicReadingMode => 'Comic reading mode';

  @override
  String get comicReadingModeDescription =>
      'Choose direction and page spread from the comic reader toolbar.';

  @override
  String get appDescription => 'A local-first reader for comics and ebooks.';

  @override
  String get version => 'Version';

  @override
  String get newCollection => 'New collection';

  @override
  String get yourLists => 'Your lists';

  @override
  String get createdCollections => 'Created collections';

  @override
  String get collectionActions => 'Collection actions';

  @override
  String get addBooks => 'Add books';

  @override
  String get editCollection => 'Edit collection';

  @override
  String get deleteCollection => 'Delete collection';

  @override
  String get collectionName => 'Collection name';

  @override
  String get collectionNameHint => 'Give this collection a name';

  @override
  String get collectionDescription => 'Description';

  @override
  String get collectionDescriptionHint =>
      'Optional details about this collection';

  @override
  String get createCollection => 'Create collection';

  @override
  String get saveCollection => 'Save collection';

  @override
  String get emptyCollectionsTitle => 'Create your first collection';

  @override
  String get emptyCollectionsDescription =>
      'Group books you want to keep together.';

  @override
  String get emptyCollectionTitle => 'This collection is empty';

  @override
  String get emptyCollectionDescription =>
      'Add books from your library to start reading.';

  @override
  String get startReading => 'Start reading';

  @override
  String get manageBooks => 'Manage books';

  @override
  String get removeBookFromCollection => 'Remove from collection';

  @override
  String get addBookToCollection => 'Add to collection';

  @override
  String get libraryEmptyTitle => 'Your library is empty';

  @override
  String get libraryEmptyDescription =>
      'Import CBZ, EPUB, PDF, or TXT files to start reading.';

  @override
  String get importBooks => 'Import books';

  @override
  String get importingBooks => 'Importing…';

  @override
  String get searchBooks => 'Search books';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get allSources => 'All sources';

  @override
  String get localSource => 'Local';

  @override
  String get opdsSource => 'OPDS';

  @override
  String get allFormats => 'All formats';

  @override
  String get allPublications => 'All';

  @override
  String get ebookFormat => 'Ebooks';

  @override
  String get enterFullScreen => 'Enter full screen';

  @override
  String get exitFullScreen => 'Exit full screen';

  @override
  String get comicFormat => 'Comic';

  @override
  String get epubFormat => 'EPUB';

  @override
  String get textFormat => 'Text';

  @override
  String get sortByTitleAscending => 'Title: A–Z';

  @override
  String get sortByTitleDescending => 'Title: Z–A';

  @override
  String get noMatchingBooks => 'No matching books';

  @override
  String get noMatchingBooksDescription =>
      'Try changing the search or filters.';

  @override
  String get libraryActions => 'Library actions';

  @override
  String get openDetails => 'Open details';

  @override
  String get removeFromLibrary => 'Remove from library';

  @override
  String get openReader => 'Open reader';

  @override
  String lastRead(String value) {
    return 'Last read $value';
  }

  @override
  String get notReadYet => 'Not read yet';

  @override
  String get unknownRoute => 'This page does not exist.';

  @override
  String get backToLibrary => 'Back to library';

  @override
  String get opdsRetryCatalog => 'Retry catalog';

  @override
  String get opdsCatalogActions => 'Catalog actions';

  @override
  String get editCatalog => 'Edit catalog';

  @override
  String get removeCatalog => 'Remove catalog';

  @override
  String get browse => 'Browse';

  @override
  String get editOpdsCatalog => 'Edit OPDS catalog';

  @override
  String get catalogName => 'Catalog name';

  @override
  String get catalogUrl => 'Catalog URL';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get validCatalogCredentialsRequired =>
      'Enter a valid URL and both credentials.';

  @override
  String get removeCatalogTitle => 'Remove catalog?';

  @override
  String removeCatalogDescription(String name) {
    return 'Remove $name from this device? Its downloaded publications remain in your library.';
  }

  @override
  String get catalogHasPublications =>
      'Remove this catalog’s downloaded publications first.';

  @override
  String get cancelDownload => 'Cancel download';

  @override
  String get downloadToLibrary => 'Download to library or refresh metadata';

  @override
  String publicationAddedToLibrary(String title) {
    return '$title added to the library.';
  }

  @override
  String get downloadCancelled => 'Download cancelled.';

  @override
  String unableToDownloadPublication(String error) {
    return 'Unable to download publication: $error';
  }

  @override
  String get readingSettings => 'Reading settings';

  @override
  String get closeSettings => 'Close settings';

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String pageProgress(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get readingMode => 'Reading mode';

  @override
  String get textPagedMode => 'Horizontal pages';

  @override
  String get textScrollMode => 'Continuous scroll';

  @override
  String get doublePageSpread => 'Double-page spread';

  @override
  String get doublePageSpreadDescription =>
      'Show two pages at a time in horizontal modes.';

  @override
  String get readerEmptyTitle => 'Nothing to read';

  @override
  String get readerEmptyDescription =>
      'This publication has no readable content.';

  @override
  String get unableToOpenComic => 'Unable to open this comic';

  @override
  String unableToOpenPublication(String error) {
    return 'Unable to open this publication.\n$error';
  }

  @override
  String get tableOfContents => 'Table of contents';

  @override
  String get closeTableOfContents => 'Close table of contents';

  @override
  String get previousChapter => 'Previous chapter';

  @override
  String get nextChapter => 'Next chapter';

  @override
  String chapterProgress(int current, int total) {
    return 'Chapter $current of $total';
  }

  @override
  String unableToLoadChapter(String error) {
    return 'Unable to load this chapter.\n$error';
  }

  @override
  String get textSize => 'Text size';

  @override
  String get lineHeight => 'Line height';

  @override
  String get pageMargins => 'Page margins';

  @override
  String get readerAppearance => 'Appearance';

  @override
  String get sepia => 'Sepia';

  @override
  String get pluginTitle => 'Built-in integrations';

  @override
  String get pluginDescription =>
      'Fbooks keeps its reading sources local-first and built in.';

  @override
  String get opdsPluginTitle => 'OPDS catalogs';

  @override
  String get opdsPluginDescription =>
      'Browse compatible catalogs and download readable publications.';

  @override
  String get localFilesPluginTitle => 'Local files';

  @override
  String get localFilesPluginDescription =>
      'Import and read files stored on this device.';

  @override
  String get notFoundTitle => 'This page is not in your library.';

  @override
  String get notFoundDescription =>
      'Return to your library and choose a book to continue.';

  @override
  String notFoundRouteDescription(String routeName) {
    return '“$routeName” is not available. Return to your library and choose a book to continue.';
  }

  @override
  String get enabled => 'Enabled';

  @override
  String get notAvailable => 'Not available';

  @override
  String get pluginsDescription =>
      'Built-in capabilities are reviewed and run locally with your library.';

  @override
  String get localFilesDescription =>
      'Import and read CBZ, EPUB, PDF, and TXT files stored on this device.';

  @override
  String localLibraryBookCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books in your local library',
      one: '1 book in your local library',
      zero: 'No books in your local library',
    );
    return '$_temp0';
  }

  @override
  String get opdsCatalogues => 'OPDS catalogues';

  @override
  String get opdsCataloguesDescription =>
      'Browse OPDS 1 and OPDS 2 catalogues and add readable titles to the library.';

  @override
  String get configureCatalogues =>
      'Configure catalogues from the Library toolbar';

  @override
  String get thirdPartyExtensions => 'Third-party extensions';

  @override
  String get thirdPartyExtensionsDescription =>
      'No external extensions are installed. fBooks does not load unreviewed reader code.';

  @override
  String get thirdPartyExtensionsDetail =>
      'A plug-in API is deliberately outside the current local-first milestone';

  @override
  String get localPdfRequired => 'A local PDF file is required.';

  @override
  String get pdfFileMissing => 'The imported PDF file is missing.';

  @override
  String unableToLoadOpdsCatalog(String error) {
    return 'Unable to load the OPDS catalog.\\n$error';
  }

  @override
  String get noAuthorMetadata => 'No author metadata';

  @override
  String get usernameOptional => 'Username (optional)';

  @override
  String get passwordOptional => 'Password (optional)';

  @override
  String unableToLoadLibrary(String error) {
    return 'Unable to load the library: $error';
  }

  @override
  String get addLocalPublications => 'Add local publications';

  @override
  String get connectOpdsCatalog => 'Connect OPDS catalog';

  @override
  String get browseOpdsCatalogs => 'Browse OPDS catalogs';

  @override
  String get connect => 'Connect';

  @override
  String get validHttpCatalogUrlRequired =>
      'Enter a valid HTTP(S) catalog URL.';

  @override
  String get usernameAndPasswordRequired =>
      'Enter both a username and password.';

  @override
  String get noOpdsCatalogs => 'No OPDS catalogs connected yet.';

  @override
  String get opdsCatalogs => 'OPDS catalogs';

  @override
  String get yourLibrary => 'Your library';

  @override
  String get libraryWelcome => 'Your library will appear here.';

  @override
  String get libraryWelcomeDescription =>
      'Start by importing a local publication or connecting an OPDS source.';

  @override
  String get searchLibrary => 'Search library';

  @override
  String get filterSource => 'Filter source';

  @override
  String get filterFormat => 'Filter format';

  @override
  String get sortPublications => 'Sort publications';

  @override
  String get noMatchingPublications => 'No matching publications';

  @override
  String get noMatchingPublicationsDescription =>
      'Try another title, author, source, or format.';

  @override
  String get publicationDetails => 'Publication details';

  @override
  String get collapseCollections => 'Collapse collections';

  @override
  String get expandCollections => 'Expand collections';

  @override
  String importSummary(int imported, int duplicates, int unsupported) {
    return '$imported added, $duplicates already in library, $unsupported unsupported.';
  }

  @override
  String unableToAddPublications(String error) {
    return 'Unable to add publications: $error';
  }

  @override
  String get connectOpds => 'Connect OPDS';
}
