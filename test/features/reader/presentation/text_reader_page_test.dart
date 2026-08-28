import 'dart:typed_data';

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
  testWidgets('follows an internal EPUB link to its target chapter', (
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
              text: 'Read the next chapter',
              segments: [
                TextSegment(
                  text: 'Read the next chapter',
                  linkTargetChapterIndex: 1,
                ),
              ],
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

  testWidgets('renders embedded EPUB images and tables', (tester) async {
    await tester.pumpWidget(
      _readerApp(
        TextDocument(
          publicationId: _publicationId,
          chapters: [
            TextChapter(
              index: 0,
              title: 'Illustrated data',
              text: '',
              segments: [
                TextSegment(
                  text: '',
                  imageBytes: Uint8List.fromList(_pixelGif),
                ),
                const TextSegment(
                  text: '',
                  table: TextTable(
                    rows: [
                      ['Year', 'Sales'],
                      ['2025', '42'],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Sales'), findsOneWidget);
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

Widget _readerApp(TextDocument document) => ProviderScope(
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
      _TextReadingPreferencesRepository(),
    ),
  ],
  child: const MaterialApp(
    home: TextReaderPage(publicationId: _publicationId, title: 'Linked book'),
  ),
);

final _pixelGif = Uint8List.fromList(const [
  71,
  73,
  70,
  56,
  57,
  97,
  1,
  0,
  1,
  0,
  128,
  0,
  0,
  0,
  0,
  0,
  255,
  255,
  255,
  44,
  0,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  1,
  0,
  0,
  2,
  1,
  76,
  0,
  59,
]);

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
}

class _ReadingProgressRepository implements ReadingProgressRepository {
  @override
  Future<ReadingProgress?> load(PublicationId publicationId) async => null;

  @override
  Future<void> save(ReadingProgress progress) async {}
}

class _TextReadingPreferencesRepository
    implements TextReadingPreferencesRepository {
  @override
  Future<TextReadingPreferences> load() async =>
      TextReadingPreferences.defaults;

  @override
  Future<void> save(TextReadingPreferences preferences) async {}
}
