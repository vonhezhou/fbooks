import 'package:fbooks/app/providers.dart';
import 'package:fbooks/app/fbooks_app.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('shows the empty library landing page', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationRepositoryProvider.overrideWithValue(
            _EmptyPublicationRepository(),
          ),
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Fbooks'), findsOneWidget);
    expect(find.text('Your library will appear here.'), findsOneWidget);
  });

  testWidgets('uses the desktop library shell in a wide window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationRepositoryProvider.overrideWithValue(
            _EmptyPublicationRepository(),
          ),
        ],
        child: const FbooksApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Your library'), findsOneWidget);
    expect(find.text('Collections'), findsOneWidget);
    expect(find.text('Add books'), findsOneWidget);
  });
}

class _EmptyPublicationRepository implements PublicationRepository {
  @override
  Future<void> delete(PublicationId id) => throw UnimplementedError();

  @override
  Future<Publication?> findById(PublicationId id) => throw UnimplementedError();

  @override
  Future<Publication?> findByAssetLocation(Uri location) =>
      throw UnimplementedError();

  @override
  Future<List<Publication>> listPublications() => Future.value(const []);

  @override
  Future<void> save(Publication publication) => throw UnimplementedError();

  @override
  Stream<List<Publication>> watchPublications() => Stream.value(const []);
}
