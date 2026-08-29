import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// The application name displayed in the system window and task switcher.
  ///
  /// In en, this message translates to:
  /// **'fBooks'**
  String get appTitle;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @collections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collections;

  /// No description provided for @plugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get plugins;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @noItems.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get noItems;

  /// A generic data loading error.
  ///
  /// In en, this message translates to:
  /// **'Unable to load: {error}'**
  String unableToLoad(String error);

  /// The number of books in a library or collection.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No books} =1{1 book} other{{count} books}}'**
  String booksCount(num count);

  /// The number of custom collections.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No custom collections} =1{1 custom collection} other{{count} custom collections}}'**
  String collectionsCount(num count);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow your device language or choose an app language.'**
  String get languageDescription;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChineseSimplified.
  ///
  /// In en, this message translates to:
  /// **'Chinese (Simplified)'**
  String get languageChineseSimplified;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @colorMode.
  ///
  /// In en, this message translates to:
  /// **'Color mode'**
  String get colorMode;

  /// No description provided for @colorModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow the system or choose a permanent reading environment.'**
  String get colorModeDescription;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// No description provided for @localLibrary.
  ///
  /// In en, this message translates to:
  /// **'Local library'**
  String get localLibrary;

  /// No description provided for @comicReadingMode.
  ///
  /// In en, this message translates to:
  /// **'Comic reading mode'**
  String get comicReadingMode;

  /// No description provided for @comicReadingModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose direction and page spread from the comic reader toolbar.'**
  String get comicReadingModeDescription;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'A local-first reader for comics and ebooks.'**
  String get appDescription;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @newCollection.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get newCollection;

  /// No description provided for @yourLists.
  ///
  /// In en, this message translates to:
  /// **'Your lists'**
  String get yourLists;

  /// No description provided for @createdCollections.
  ///
  /// In en, this message translates to:
  /// **'Created collections'**
  String get createdCollections;

  /// No description provided for @collectionActions.
  ///
  /// In en, this message translates to:
  /// **'Collection actions'**
  String get collectionActions;

  /// No description provided for @addBooks.
  ///
  /// In en, this message translates to:
  /// **'Add books'**
  String get addBooks;

  /// No description provided for @editCollection.
  ///
  /// In en, this message translates to:
  /// **'Edit collection'**
  String get editCollection;

  /// No description provided for @deleteCollection.
  ///
  /// In en, this message translates to:
  /// **'Delete collection'**
  String get deleteCollection;

  /// No description provided for @collectionName.
  ///
  /// In en, this message translates to:
  /// **'Collection name'**
  String get collectionName;

  /// No description provided for @collectionNameHint.
  ///
  /// In en, this message translates to:
  /// **'Give this collection a name'**
  String get collectionNameHint;

  /// No description provided for @collectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get collectionDescription;

  /// No description provided for @collectionDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Optional details about this collection'**
  String get collectionDescriptionHint;

  /// No description provided for @createCollection.
  ///
  /// In en, this message translates to:
  /// **'Create collection'**
  String get createCollection;

  /// No description provided for @saveCollection.
  ///
  /// In en, this message translates to:
  /// **'Save collection'**
  String get saveCollection;

  /// No description provided for @emptyCollectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first collection'**
  String get emptyCollectionsTitle;

  /// No description provided for @emptyCollectionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Group books you want to keep together.'**
  String get emptyCollectionsDescription;

  /// No description provided for @emptyCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'This collection is empty'**
  String get emptyCollectionTitle;

  /// No description provided for @emptyCollectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Add books from your library to start reading.'**
  String get emptyCollectionDescription;

  /// No description provided for @startReading.
  ///
  /// In en, this message translates to:
  /// **'Start reading'**
  String get startReading;

  /// No description provided for @manageBooks.
  ///
  /// In en, this message translates to:
  /// **'Manage books'**
  String get manageBooks;

  /// No description provided for @removeBookFromCollection.
  ///
  /// In en, this message translates to:
  /// **'Remove from collection'**
  String get removeBookFromCollection;

  /// No description provided for @addBookToCollection.
  ///
  /// In en, this message translates to:
  /// **'Add to collection'**
  String get addBookToCollection;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Import CBZ, EPUB, PDF, or TXT files to start reading.'**
  String get libraryEmptyDescription;

  /// No description provided for @importBooks.
  ///
  /// In en, this message translates to:
  /// **'Import books'**
  String get importBooks;

  /// No description provided for @importingBooks.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get importingBooks;

  /// No description provided for @searchBooks.
  ///
  /// In en, this message translates to:
  /// **'Search books'**
  String get searchBooks;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @allSources.
  ///
  /// In en, this message translates to:
  /// **'All sources'**
  String get allSources;

  /// No description provided for @localSource.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get localSource;

  /// No description provided for @opdsSource.
  ///
  /// In en, this message translates to:
  /// **'OPDS'**
  String get opdsSource;

  /// No description provided for @allFormats.
  ///
  /// In en, this message translates to:
  /// **'All formats'**
  String get allFormats;

  /// No description provided for @comicFormat.
  ///
  /// In en, this message translates to:
  /// **'Comic'**
  String get comicFormat;

  /// No description provided for @epubFormat.
  ///
  /// In en, this message translates to:
  /// **'EPUB'**
  String get epubFormat;

  /// No description provided for @textFormat.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textFormat;

  /// No description provided for @sortByTitleAscending.
  ///
  /// In en, this message translates to:
  /// **'Title: A–Z'**
  String get sortByTitleAscending;

  /// No description provided for @sortByTitleDescending.
  ///
  /// In en, this message translates to:
  /// **'Title: Z–A'**
  String get sortByTitleDescending;

  /// No description provided for @noMatchingBooks.
  ///
  /// In en, this message translates to:
  /// **'No matching books'**
  String get noMatchingBooks;

  /// No description provided for @noMatchingBooksDescription.
  ///
  /// In en, this message translates to:
  /// **'Try changing the search or filters.'**
  String get noMatchingBooksDescription;

  /// No description provided for @libraryActions.
  ///
  /// In en, this message translates to:
  /// **'Library actions'**
  String get libraryActions;

  /// No description provided for @openDetails.
  ///
  /// In en, this message translates to:
  /// **'Open details'**
  String get openDetails;

  /// No description provided for @removeFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get removeFromLibrary;

  /// No description provided for @openReader.
  ///
  /// In en, this message translates to:
  /// **'Open reader'**
  String get openReader;

  /// The last-reading date label.
  ///
  /// In en, this message translates to:
  /// **'Last read {value}'**
  String lastRead(String value);

  /// No description provided for @notReadYet.
  ///
  /// In en, this message translates to:
  /// **'Not read yet'**
  String get notReadYet;

  /// No description provided for @unknownRoute.
  ///
  /// In en, this message translates to:
  /// **'This page does not exist.'**
  String get unknownRoute;

  /// No description provided for @backToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Back to library'**
  String get backToLibrary;

  /// No description provided for @opdsRetryCatalog.
  ///
  /// In en, this message translates to:
  /// **'Retry catalog'**
  String get opdsRetryCatalog;

  /// No description provided for @opdsCatalogActions.
  ///
  /// In en, this message translates to:
  /// **'Catalog actions'**
  String get opdsCatalogActions;

  /// No description provided for @editCatalog.
  ///
  /// In en, this message translates to:
  /// **'Edit catalog'**
  String get editCatalog;

  /// No description provided for @removeCatalog.
  ///
  /// In en, this message translates to:
  /// **'Remove catalog'**
  String get removeCatalog;

  /// No description provided for @browse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browse;

  /// No description provided for @editOpdsCatalog.
  ///
  /// In en, this message translates to:
  /// **'Edit OPDS catalog'**
  String get editOpdsCatalog;

  /// No description provided for @catalogName.
  ///
  /// In en, this message translates to:
  /// **'Catalog name'**
  String get catalogName;

  /// No description provided for @catalogUrl.
  ///
  /// In en, this message translates to:
  /// **'Catalog URL'**
  String get catalogUrl;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @validCatalogCredentialsRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid URL and both credentials.'**
  String get validCatalogCredentialsRequired;

  /// No description provided for @removeCatalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove catalog?'**
  String get removeCatalogTitle;

  /// Confirmation before deleting an OPDS catalog.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this device? Its downloaded publications remain in your library.'**
  String removeCatalogDescription(String name);

  /// No description provided for @catalogHasPublications.
  ///
  /// In en, this message translates to:
  /// **'Remove this catalog’s downloaded publications first.'**
  String get catalogHasPublications;

  /// No description provided for @cancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get cancelDownload;

  /// No description provided for @downloadToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Download to library or refresh metadata'**
  String get downloadToLibrary;

  /// Successful OPDS download notification.
  ///
  /// In en, this message translates to:
  /// **'{title} added to the library.'**
  String publicationAddedToLibrary(String title);

  /// No description provided for @downloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled.'**
  String get downloadCancelled;

  /// An OPDS download failure.
  ///
  /// In en, this message translates to:
  /// **'Unable to download publication: {error}'**
  String unableToDownloadPublication(String error);

  /// No description provided for @readingSettings.
  ///
  /// In en, this message translates to:
  /// **'Reading settings'**
  String get readingSettings;

  /// No description provided for @closeSettings.
  ///
  /// In en, this message translates to:
  /// **'Close settings'**
  String get closeSettings;

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// The current page and total comic page count.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pageProgress(int current, int total);

  /// No description provided for @readingMode.
  ///
  /// In en, this message translates to:
  /// **'Reading mode'**
  String get readingMode;

  /// No description provided for @doublePageSpread.
  ///
  /// In en, this message translates to:
  /// **'Double-page spread'**
  String get doublePageSpread;

  /// No description provided for @doublePageSpreadDescription.
  ///
  /// In en, this message translates to:
  /// **'Show two pages at a time in horizontal modes.'**
  String get doublePageSpreadDescription;

  /// No description provided for @readerEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to read'**
  String get readerEmptyTitle;

  /// No description provided for @readerEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'This publication has no readable content.'**
  String get readerEmptyDescription;

  /// No description provided for @unableToOpenComic.
  ///
  /// In en, this message translates to:
  /// **'Unable to open this comic'**
  String get unableToOpenComic;

  /// A reader loading failure.
  ///
  /// In en, this message translates to:
  /// **'Unable to open this publication.\n{error}'**
  String unableToOpenPublication(String error);

  /// No description provided for @tableOfContents.
  ///
  /// In en, this message translates to:
  /// **'Table of contents'**
  String get tableOfContents;

  /// No description provided for @closeTableOfContents.
  ///
  /// In en, this message translates to:
  /// **'Close table of contents'**
  String get closeTableOfContents;

  /// No description provided for @previousChapter.
  ///
  /// In en, this message translates to:
  /// **'Previous chapter'**
  String get previousChapter;

  /// No description provided for @nextChapter.
  ///
  /// In en, this message translates to:
  /// **'Next chapter'**
  String get nextChapter;

  /// The current chapter and total chapter count.
  ///
  /// In en, this message translates to:
  /// **'Chapter {current} of {total}'**
  String chapterProgress(int current, int total);

  /// A chapter loading failure.
  ///
  /// In en, this message translates to:
  /// **'Unable to load this chapter.\n{error}'**
  String unableToLoadChapter(String error);

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @lineHeight.
  ///
  /// In en, this message translates to:
  /// **'Line height'**
  String get lineHeight;

  /// No description provided for @pageMargins.
  ///
  /// In en, this message translates to:
  /// **'Page margins'**
  String get pageMargins;

  /// No description provided for @readerAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get readerAppearance;

  /// No description provided for @sepia.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get sepia;

  /// No description provided for @pluginTitle.
  ///
  /// In en, this message translates to:
  /// **'Built-in integrations'**
  String get pluginTitle;

  /// No description provided for @pluginDescription.
  ///
  /// In en, this message translates to:
  /// **'Fbooks keeps its reading sources local-first and built in.'**
  String get pluginDescription;

  /// No description provided for @opdsPluginTitle.
  ///
  /// In en, this message translates to:
  /// **'OPDS catalogs'**
  String get opdsPluginTitle;

  /// No description provided for @opdsPluginDescription.
  ///
  /// In en, this message translates to:
  /// **'Browse compatible catalogs and download readable publications.'**
  String get opdsPluginDescription;

  /// No description provided for @localFilesPluginTitle.
  ///
  /// In en, this message translates to:
  /// **'Local files'**
  String get localFilesPluginTitle;

  /// No description provided for @localFilesPluginDescription.
  ///
  /// In en, this message translates to:
  /// **'Import and read files stored on this device.'**
  String get localFilesPluginDescription;

  /// No description provided for @notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'This page is not in your library.'**
  String get notFoundTitle;

  /// No description provided for @notFoundDescription.
  ///
  /// In en, this message translates to:
  /// **'Return to your library and choose a book to continue.'**
  String get notFoundDescription;

  /// Description for an unavailable route.
  ///
  /// In en, this message translates to:
  /// **'“{routeName}” is not available. Return to your library and choose a book to continue.'**
  String notFoundRouteDescription(String routeName);

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @pluginsDescription.
  ///
  /// In en, this message translates to:
  /// **'Built-in capabilities are reviewed and run locally with your library.'**
  String get pluginsDescription;

  /// No description provided for @localFilesDescription.
  ///
  /// In en, this message translates to:
  /// **'Import and read CBZ, EPUB, PDF, and TXT files stored on this device.'**
  String get localFilesDescription;

  /// The number of books currently in the local library.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No books in your local library} =1{1 book in your local library} other{{count} books in your local library}}'**
  String localLibraryBookCount(num count);

  /// No description provided for @opdsCatalogues.
  ///
  /// In en, this message translates to:
  /// **'OPDS catalogues'**
  String get opdsCatalogues;

  /// No description provided for @opdsCataloguesDescription.
  ///
  /// In en, this message translates to:
  /// **'Browse OPDS 1 and OPDS 2 catalogues and add readable titles to the library.'**
  String get opdsCataloguesDescription;

  /// No description provided for @configureCatalogues.
  ///
  /// In en, this message translates to:
  /// **'Configure catalogues from the Library toolbar'**
  String get configureCatalogues;

  /// No description provided for @thirdPartyExtensions.
  ///
  /// In en, this message translates to:
  /// **'Third-party extensions'**
  String get thirdPartyExtensions;

  /// No description provided for @thirdPartyExtensionsDescription.
  ///
  /// In en, this message translates to:
  /// **'No external extensions are installed. fBooks does not load unreviewed reader code.'**
  String get thirdPartyExtensionsDescription;

  /// No description provided for @thirdPartyExtensionsDetail.
  ///
  /// In en, this message translates to:
  /// **'A plug-in API is deliberately outside the current local-first milestone'**
  String get thirdPartyExtensionsDetail;

  /// No description provided for @localPdfRequired.
  ///
  /// In en, this message translates to:
  /// **'A local PDF file is required.'**
  String get localPdfRequired;

  /// No description provided for @pdfFileMissing.
  ///
  /// In en, this message translates to:
  /// **'The imported PDF file is missing.'**
  String get pdfFileMissing;

  /// An OPDS catalog loading failure.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the OPDS catalog.\\n{error}'**
  String unableToLoadOpdsCatalog(String error);

  /// No description provided for @noAuthorMetadata.
  ///
  /// In en, this message translates to:
  /// **'No author metadata'**
  String get noAuthorMetadata;

  /// No description provided for @usernameOptional.
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get usernameOptional;

  /// No description provided for @passwordOptional.
  ///
  /// In en, this message translates to:
  /// **'Password (optional)'**
  String get passwordOptional;

  /// A library loading failure.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the library: {error}'**
  String unableToLoadLibrary(String error);

  /// No description provided for @addLocalPublications.
  ///
  /// In en, this message translates to:
  /// **'Add local publications'**
  String get addLocalPublications;

  /// No description provided for @connectOpdsCatalog.
  ///
  /// In en, this message translates to:
  /// **'Connect OPDS catalog'**
  String get connectOpdsCatalog;

  /// No description provided for @browseOpdsCatalogs.
  ///
  /// In en, this message translates to:
  /// **'Browse OPDS catalogs'**
  String get browseOpdsCatalogs;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @validHttpCatalogUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP(S) catalog URL.'**
  String get validHttpCatalogUrlRequired;

  /// No description provided for @usernameAndPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter both a username and password.'**
  String get usernameAndPasswordRequired;

  /// No description provided for @noOpdsCatalogs.
  ///
  /// In en, this message translates to:
  /// **'No OPDS catalogs connected yet.'**
  String get noOpdsCatalogs;

  /// No description provided for @opdsCatalogs.
  ///
  /// In en, this message translates to:
  /// **'OPDS catalogs'**
  String get opdsCatalogs;

  /// No description provided for @yourLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your library'**
  String get yourLibrary;

  /// No description provided for @libraryWelcome.
  ///
  /// In en, this message translates to:
  /// **'Your library will appear here.'**
  String get libraryWelcome;

  /// No description provided for @libraryWelcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Start by importing a local publication or connecting an OPDS source.'**
  String get libraryWelcomeDescription;

  /// No description provided for @searchLibrary.
  ///
  /// In en, this message translates to:
  /// **'Search library'**
  String get searchLibrary;

  /// No description provided for @filterSource.
  ///
  /// In en, this message translates to:
  /// **'Filter source'**
  String get filterSource;

  /// No description provided for @filterFormat.
  ///
  /// In en, this message translates to:
  /// **'Filter format'**
  String get filterFormat;

  /// No description provided for @sortPublications.
  ///
  /// In en, this message translates to:
  /// **'Sort publications'**
  String get sortPublications;

  /// No description provided for @noMatchingPublications.
  ///
  /// In en, this message translates to:
  /// **'No matching publications'**
  String get noMatchingPublications;

  /// No description provided for @noMatchingPublicationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Try another title, author, source, or format.'**
  String get noMatchingPublicationsDescription;

  /// No description provided for @publicationDetails.
  ///
  /// In en, this message translates to:
  /// **'Publication details'**
  String get publicationDetails;

  /// No description provided for @collapseCollections.
  ///
  /// In en, this message translates to:
  /// **'Collapse collections'**
  String get collapseCollections;

  /// No description provided for @expandCollections.
  ///
  /// In en, this message translates to:
  /// **'Expand collections'**
  String get expandCollections;

  /// Summary after importing local publications.
  ///
  /// In en, this message translates to:
  /// **'{imported} added, {duplicates} already in library, {unsupported} unsupported.'**
  String importSummary(int imported, int duplicates, int unsupported);

  /// A local import failure.
  ///
  /// In en, this message translates to:
  /// **'Unable to add publications: {error}'**
  String unableToAddPublications(String error);

  /// No description provided for @connectOpds.
  ///
  /// In en, this message translates to:
  /// **'Connect OPDS'**
  String get connectOpds;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
