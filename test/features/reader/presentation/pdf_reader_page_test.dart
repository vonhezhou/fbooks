import 'dart:async';

import 'package:fbooks/app/providers.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/features/reader/presentation/pdf_reader_page.dart';
import 'package:fbooks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'waits for PDF progress and keeps unavailable-file controls usable',
    (tester) async {
      final progress = Completer<ReadingProgress?>();
      final repository = _PublicationRepository(_publication());
      await tester.pumpWidget(_app(repository, progress: progress.future));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('A local PDF file is required.'), findsNothing);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byKey(const Key('reader-page-input')), findsNothing);

      progress.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('A local PDF file is required.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(repository.findCalls, 1);
    },
  );

  testWidgets(
    'PDF theme rebuild preserves metadata lookup and the missing-file state',
    (tester) async {
      final repository = _PublicationRepository(
        _publication(
          assets: [
            PublicationAsset(
              id: 'pdf-file',
              publicationId: 'pdf',
              kind: PublicationAssetKind.localFile,
              location: Uri.file('/missing-fbooks-reader-test.pdf'),
            ),
          ],
        ),
      );
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(find.text('The imported PDF file is missing.'), findsOneWidget);
      await tester.pumpWidget(_app(repository, dark: true));
      await tester.pumpAndSettle();
      expect(find.text('The imported PDF file is missing.'), findsOneWidget);
      expect(repository.findCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows PDF loading failures with a close action', (tester) async {
    await tester.pumpWidget(_app(_PublicationRepository(null, fail: true)));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Unable to open this publication.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byKey(const Key('reader-page-input')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Publication _publication({List<PublicationAsset> assets = const []}) =>
    Publication(
      id: 'pdf',
      source: const LibrarySource(
        id: 'local',
        kind: LibrarySourceKind.local,
        name: 'Local',
      ),
      title: 'PDF book',
      format: PublicationFormat.pdf,
      assets: assets,
    );

Widget _app(
  _PublicationRepository repository, {
  Future<ReadingProgress?>? progress,
  bool dark = false,
}) => ProviderScope(
  overrides: [
    publicationRepositoryProvider.overrideWithValue(repository),
    readingProgressProvider('pdf')
        .overrideWith((ref) => progress ?? Future.value(null)),
  ],
  child: MaterialApp(
    theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const PdfReaderPage(publicationId: 'pdf', title: 'PDF book'),
  ),
);

class _PublicationRepository extends Fake implements PublicationRepository {
  _PublicationRepository(this.publication, {this.fail = false});
  final Publication? publication;
  final bool fail;
  var findCalls = 0;

  @override
  Future<Publication?> findById(PublicationId id) async {
    findCalls++;
    if (fail) throw StateError('Metadata unavailable');
    return publication;
  }
}
