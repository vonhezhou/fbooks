import 'package:fbooks/app/providers.dart';
import 'package:fbooks/application/reader/text_reader_session.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/reading_progress_repository.dart';
import 'package:fbooks/domain/reading/text_document.dart';
import 'package:fbooks/domain/reading/text_reading_preferences.dart';
import 'package:fbooks/domain/reading/text_reading_preferences_repository.dart';
import 'package:fbooks/features/reader/presentation/text_reader_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('follows an internal EPUB link rendered from XHTML', (
    tester,
  ) async {
    await tester.pumpWidget(
      _readerApp(
        const TextDocument(
          publicationId: _publicationId,
          chapters: [
            TextChapter(
              index: 0,
              title: 'First',
              text: '',
              html: '<p><a href="fbooks://chapter/1">Read the next chapter</a></p>',
            ),
            TextChapter(index: 1, title: 'Second', text: 'Arrival'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read the next chapter'));
    await tester.pumpAndSettle();

    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Arrival'), findsOneWidget);
  });

  testWidgets('renders EPUB XHTML images and tables', (tester) async {
    await tester.pumpWidget(
      _readerApp(
        TextDocument(
          publicationId: _publicationId,
          chapters: [
            TextChapter(
              index: 0,
              title: 'Illustrated data',
              text: '',
              html:
                  '<p><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==" /></p>'
                  '<table><tr><th>Year</th><th>Sales</th></tr>'
                  '<tr><td>2025</td><td>42</td></tr></table>',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Sales'), findsOneWidget);
  });

  testWidgets('uses floating controls on desktop', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _readerApp(
        const TextDocument(
          publicationId: _publicationId,
          chapters: [TextChapter(index: 0, title: 'First', text: 'Read')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('text-reader-desktop-controls')),
      findsOneWidget,
    );
    expect(find.byTooltip('Reading settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a dark right-side panel for desktop settings', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _readerApp(
        const TextDocument(
          publicationId: _publicationId,
          chapters: [TextChapter(index: 0, title: 'First', text: 'Read')],
        ),
        preferences: const TextReadingPreferences(
          appearance: TextReadingAppearance.dark,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reading settings'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('text-reader-desktop-settings')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopRight(find.byKey(const Key('text-reader-desktop-settings')))
          .dx,
      1200,
    );
    final surface = tester.widget<Material>(
      find.byKey(const Key('text-reading-settings-surface')),
    );
    expect(surface.color, const Color(0xFF1C1D20));
  });

  testWidgets('uses a bottom sheet for compact settings', (tester) async {
    await tester.pumpWidget(
      _readerApp(
        const TextDocument(
          publicationId: _publicationId,
          chapters: [TextChapter(index: 0, title: 'First', text: 'Read')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reading settings'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('text-reader-desktop-settings')), findsNothing);
  });

  testWidgets('uses a dark left-side panel for the desktop table of contents', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _readerApp(
        _documentWithTableOfContents,
        preferences: const TextReadingPreferences(
          appearance: TextReadingAppearance.dark,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Table of contents'));
    await tester.pumpAndSettle();

    final panel = find.byKey(
      const Key('text-reader-desktop-table-of-contents'),
    );
    expect(panel, findsOneWidget);
    expect(tester.getTopLeft(panel).dx, 0);
    final surface = tester.widget<Material>(
      find.byKey(const Key('text-reader-table-of-contents-surface')),
    );
    expect(surface.color, const Color(0xFF1C1D20));
  });

  testWidgets('uses a full-screen dialog for the compact table of contents', (
    tester,
  ) async {
    await tester.pumpWidget(_readerApp(_documentWithTableOfContents));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Table of contents'));
    await tester.pumpAndSettle();

    final surface = find.byKey(
      const Key('text-reader-table-of-contents-surface'),
    );
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.getSize(surface), tester.getSize(find.byType(MaterialApp)));
  });
}

const _publicationId = 'linked-book';

const _publication = Publication(
  id: _publicationId,
  source: LibrarySource(
    id: 'local-library',
    kind: LibrarySourceKind.local,
    name: 'Local library',
  ),
  title: 'Linked book',
  format: PublicationFormat.epub,
);

const _documentWithTableOfContents = TextDocument(
  publicationId: _publicationId,
  chapters: [
    TextChapter(index: 0, title: 'First', text: 'Read'),
    TextChapter(index: 1, title: 'Second', text: 'Continue'),
  ],
  tableOfContents: [
    TextTableOfContentsEntry(title: 'First chapter', chapterIndex: 0),
    TextTableOfContentsEntry(title: 'Second chapter', chapterIndex: 1),
  ],
);

Widget _readerApp(
  TextDocument document, {
  TextReadingPreferences preferences = TextReadingPreferences.defaults,
}) => ProviderScope(
  overrides: [
    publicationRepositoryProvider.overrideWithValue(
      _PublicationRepository(_publication),
    ),
    textReaderSessionFactoryProvider.overrideWithValue(
      _TextReaderSessionFactory(document),
    ),
    readingProgressRepositoryProvider.overrideWithValue(
      _ReadingProgressRepository(),
    ),
    textReadingPreferencesRepositoryProvider.overrideWithValue(
      _TextReadingPreferencesRepository(preferences),
    ),
  ],
  child: const MaterialApp(
    home: TextReaderPage(publicationId: _publicationId, title: 'Linked book'),
  ),
);

class _PublicationRepository implements PublicationRepository {
  const _PublicationRepository(this.publication);

  final Publication publication;

  @override
  Future<void> delete(PublicationId id) => throw UnimplementedError();

  @override
  Future<Publication?> findById(PublicationId id) async => publication;

  @override
  Future<Publication?> findByAssetLocation(Uri location) =>
      throw UnimplementedError();

  @override
  Future<List<Publication>> listPublications() async => [publication];

  @override
  Future<void> save(Publication publication) => throw UnimplementedError();

  @override
  Stream<List<Publication>> watchPublications() => Stream.value([publication]);
}

class _TextReaderSessionFactory implements TextReaderSessionFactory {
  const _TextReaderSessionFactory(this.document);

  final TextDocument document;

  @override
  Future<TextReaderSession> open(Publication publication) async =>
      _TextReaderSession(document);
}

class _TextReaderSession implements TextReaderSession {
  const _TextReaderSession(this.document);

  @override
  final TextDocument document;

  @override
  Future<TextChapter> loadChapter(int index) async => document.chapters[index];

  @override
  Future<void> close() async {}
}

class _ReadingProgressRepository implements ReadingProgressRepository {
  @override
  Future<ReadingProgress?> load(PublicationId publicationId) async => null;

  @override
  Future<void> save(ReadingProgress progress) async {}
}

class _TextReadingPreferencesRepository
    implements TextReadingPreferencesRepository {
  _TextReadingPreferencesRepository(this.preferences);

  TextReadingPreferences preferences;

  @override
  Future<TextReadingPreferences> load() async => preferences;

  @override
  Future<void> save(TextReadingPreferences preferences) async {
    this.preferences = preferences;
  }
}
