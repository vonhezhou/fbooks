import 'package:fbooks/app/providers.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/domain/reading/reading_progress_repository.dart';
import 'package:fbooks/features/library/presentation/publication_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows publication metadata and the saved reading position', (
    tester,
  ) async {
    const publicationId = 'the-garden';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingProgressRepositoryProvider.overrideWithValue(
            _FixedProgressRepository(
              ReadingProgress(
                publicationId: publicationId,
                locator: TextOffsetLocator(chapterIndex: 2, offset: 240),
                updatedAt: DateTime(2026),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: PublicationDetailsPage(
            publication: const Publication(
              id: publicationId,
              source: LibrarySource(
                id: 'local-library',
                kind: LibrarySourceKind.local,
                name: 'Local library',
              ),
              title: 'The Garden',
              authors: ['Ada Lovelace'],
              description: 'An illustrated story about a garden.',
              format: PublicationFormat.epub,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('The Garden'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('EPUB ebook'), findsOneWidget);
    expect(find.text('Local library'), findsOneWidget);
    expect(find.text('Chapter 3'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('An illustrated story about a garden.'),
      240,
    );
    expect(find.text('An illustrated story about a garden.'), findsOneWidget);
    expect(find.text('Continue reading'), findsOneWidget);
  });
}

class _FixedProgressRepository implements ReadingProgressRepository {
  const _FixedProgressRepository(this.progress);

  final ReadingProgress? progress;

  @override
  Future<ReadingProgress?> load(PublicationId publicationId) async => progress;

  @override
  Future<void> save(ReadingProgress progress) async {}
}
