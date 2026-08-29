import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/features/library/presentation/publication_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const source = LibrarySource(
    id: 'local-library',
    kind: LibrarySourceKind.local,
    name: 'Local library',
  );

  testWidgets('uses the generated default-cover asset when no cover exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 180,
            child: PublicationCover(
              publication: Publication(
                id: 'without-cover',
                source: source,
                title: 'Without cover',
                format: PublicationFormat.epub,
              ),
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));

    expect(image.image, isA<AssetImage>());
  });

  testWidgets('prefers a generated cover asset over the remote cover URI', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 180,
            child: PublicationCover(
              publication: Publication(
                id: 'with-cover',
                source: source,
                title: 'With cover',
                format: PublicationFormat.comicArchive,
                coverUri: Uri.parse('https://example.test/cover.jpg'),
                assets: [
                  PublicationAsset(
                    id: 'generated-cover',
                    publicationId: 'with-cover',
                    kind: PublicationAssetKind.coverImage,
                    location: Uri.file('/managed/cover.jpg'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));

    expect(image.image, isA<FileImage>());
  });
}
