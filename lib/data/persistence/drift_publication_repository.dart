import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fbooks/data/persistence/local_database.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';

class DriftPublicationRepository implements PublicationRepository {
  DriftPublicationRepository(this._database);

  final LocalDatabase _database;

  @override
  Future<void> delete(PublicationId id) async {
    await (_database.delete(
      _database.storedPublications,
    )..where((publication) => publication.id.equals(id))).go();
  }

  @override
  Future<Publication?> findById(PublicationId id) async {
    final publication = await (_database.select(
      _database.storedPublications,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (publication == null) {
      return null;
    }

    return _loadDomainPublication(publication);
  }

  @override
  Future<Publication?> findByAssetLocation(Uri location) async {
    final asset =
        await (_database.select(_database.storedPublicationAssets)
              ..where((row) => row.location.equals(location.toString())))
            .getSingleOrNull();
    return asset == null ? null : findById(asset.publicationId);
  }

  @override
  Future<List<Publication>> listPublications() async {
    final publications = await _database
        .select(_database.storedPublications)
        .get();
    return _toDomainList(publications);
  }

  @override
  Future<void> save(Publication publication) async {
    await _database.transaction(() async {
      await _database
          .into(_database.storedLibrarySources)
          .insertOnConflictUpdate(
            StoredLibrarySourcesCompanion.insert(
              id: publication.source.id,
              kind: publication.source.kind.name,
              name: publication.source.name,
              endpoint: Value(publication.source.endpoint?.toString()),
              createdAt: DateTime.now(),
            ),
          );

      await _database
          .into(_database.storedPublications)
          .insertOnConflictUpdate(
            StoredPublicationsCompanion.insert(
              id: publication.id,
              sourceId: publication.source.id,
              title: publication.title,
              authorsJson: Value(jsonEncode(publication.authors)),
              format: publication.format.name,
              description: Value(publication.description),
              coverUri: Value(publication.coverUri?.toString()),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      await (_database.delete(
        _database.storedPublicationAssets,
      )..where((asset) => asset.publicationId.equals(publication.id))).go();
      await _database.batch((batch) {
        for (final asset in publication.assets) {
          if (asset.publicationId != publication.id) {
            throw ArgumentError.value(
              asset.publicationId,
              'asset.publicationId',
              'must match the publication id',
            );
          }
          batch.insert(
            _database.storedPublicationAssets,
            StoredPublicationAssetsCompanion.insert(
              id: asset.id,
              publicationId: asset.publicationId,
              kind: asset.kind.name,
              location: asset.location.toString(),
              mediaType: Value(asset.mediaType),
              createdAt: DateTime.now(),
            ),
          );
        }
      });
    });
  }

  @override
  Stream<List<Publication>> watchPublications() {
    return _database
        .select(_database.storedPublications)
        .watch()
        .asyncMap(_toDomainList);
  }

  Future<List<Publication>> _toDomainList(
    List<StoredPublication> publications,
  ) async {
    final sourceRows = await _database
        .select(_database.storedLibrarySources)
        .get();
    final assetRows = await _database
        .select(_database.storedPublicationAssets)
        .get();
    final sourceById = {for (final source in sourceRows) source.id: source};
    final assetsByPublicationId = <String, List<StoredPublicationAsset>>{};
    for (final asset in assetRows) {
      assetsByPublicationId
          .putIfAbsent(asset.publicationId, () => [])
          .add(asset);
    }
    return publications
        .map(
          (publication) => _toPublication(
            publication,
            source: sourceById[publication.sourceId],
            assets: assetsByPublicationId[publication.id] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  Future<Publication> _loadDomainPublication(
    StoredPublication publication,
  ) async {
    final source = await (_database.select(
      _database.storedLibrarySources,
    )..where((row) => row.id.equals(publication.sourceId))).getSingle();
    final assets = await (_database.select(
      _database.storedPublicationAssets,
    )..where((row) => row.publicationId.equals(publication.id))).get();
    return _toPublication(publication, source: source, assets: assets);
  }

  Publication _toPublication(
    StoredPublication publication, {
    required StoredLibrarySource? source,
    required List<StoredPublicationAsset> assets,
  }) {
    if (source == null) {
      throw StateError('Publication ${publication.id} has no library source');
    }

    final authors = (jsonDecode(publication.authorsJson) as List<Object?>)
        .whereType<String>()
        .toList(growable: false);
    return Publication(
      id: publication.id,
      source: LibrarySource(
        id: source.id,
        kind: LibrarySourceKind.values.byName(source.kind),
        name: source.name,
        endpoint: source.endpoint == null ? null : Uri.parse(source.endpoint!),
      ),
      title: publication.title,
      authors: authors,
      format: PublicationFormat.values.byName(publication.format),
      description: publication.description,
      coverUri: publication.coverUri == null
          ? null
          : Uri.parse(publication.coverUri!),
      assets: assets
          .map(
            (asset) => PublicationAsset(
              id: asset.id,
              publicationId: asset.publicationId,
              kind: PublicationAssetKind.values.byName(asset.kind),
              location: Uri.parse(asset.location),
              mediaType: asset.mediaType,
            ),
          )
          .toList(growable: false),
    );
  }
}
