import 'dart:io';
import 'dart:typed_data';

import 'package:fbooks/application/managed_asset_store.dart';
import 'package:fbooks/application/library/publication_cover_store.dart';
import 'package:fbooks/application/library/publication_format_inspector.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

final _logger = Logger('library.import');

class LocalPublicationCandidate {
  const LocalPublicationCandidate({
    required this.fileName,
    required this.location,
  });

  final String fileName;
  final Uri location;
}

abstract interface class LocalPublicationPicker {
  Future<List<LocalPublicationCandidate>> pick();

  Future<LocalPublicationCandidate?> pickReplacement(PublicationFormat format);
}

class LocalPublicationImportResult {
  const LocalPublicationImportResult({
    required this.imported,
    required this.duplicates,
    required this.unsupported,
  });

  final List<Publication> imported;
  final List<LocalPublicationCandidate> duplicates;
  final List<LocalPublicationCandidate> unsupported;
}

class LocalPublicationImporter {
  LocalPublicationImporter(
    this._repository,
    this._managedAssetStore, {
    this.publicationFormatInspector,
    this.publicationCoverStore,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  static const _localSource = LibrarySource(
    id: 'local-library',
    kind: LibrarySourceKind.local,
    name: 'Local library',
  );

  final PublicationRepository _repository;
  final ManagedAssetStore _managedAssetStore;
  final PublicationFormatInspector? publicationFormatInspector;
  final PublicationCoverStore? publicationCoverStore;
  final Uuid _uuid;

  Future<LocalPublicationImportResult> importCandidates(
    List<LocalPublicationCandidate> candidates,
  ) async {
    _logger.info('Local import started: candidates=${candidates.length}.');
    final imported = <Publication>[];
    final duplicates = <LocalPublicationCandidate>[];
    final unsupported = <LocalPublicationCandidate>[];

    for (final candidate in candidates) {
      final format = PublicationFormatDetector.fromFileName(candidate.fileName);
      if (format == null) {
        unsupported.add(candidate);
        continue;
      }

      if (await _repository.findByAssetLocation(candidate.location) != null) {
        duplicates.add(candidate);
        continue;
      }

      final publicationId = _uuid.v4();
      final managedAssetId = _uuid.v4();
      final managedLocations = <Uri>[];
      try {
        final managedLocation = await _managedAssetStore.save(
          assetId: managedAssetId,
          fileName: candidate.fileName,
          bytes: File.fromUri(candidate.location)
              .openRead()
              .map(Uint8List.fromList),
        );
        managedLocations.add(managedLocation);
        var publication = Publication(
          id: publicationId,
          source: _localSource,
          title: path.basenameWithoutExtension(candidate.fileName),
          format: format,
          assets: [
            PublicationAsset(
              id: _uuid.v4(),
              publicationId: publicationId,
              kind: PublicationAssetKind.importedSource,
              location: candidate.location,
              mediaType: PublicationFormatDetector.mediaTypeFor(format),
            ),
            PublicationAsset(
              id: managedAssetId,
              publicationId: publicationId,
              kind: PublicationAssetKind.managedFile,
              location: managedLocation,
              mediaType: PublicationFormatDetector.mediaTypeFor(format),
            ),
          ],
        );
        final inspection = await publicationFormatInspector?.inspect(
          format: format,
          location: managedLocation,
        );
        if (inspection?.metadata case final metadata?) {
          publication = metadata.applyTo(publication);
        }
        if (inspection?.cover case final cover?) {
          final coverAsset = await publicationCoverStore?.save(
            publication: publication,
            payload: cover,
          );
          if (coverAsset != null) {
            managedLocations.add(coverAsset.location);
            publication = publicationCoverStore!.replace(
              publication,
              coverAsset,
            );
          }
        }
        await _repository.save(publication);
        imported.add(publication);
        _logger.info('Local import completed: format=${format.name}.');
      } catch (error, stackTrace) {
        _logger.severe(
          'Local import failed: format=${format.name}, '
          'errorType=${error.runtimeType}.',
          null,
          stackTrace,
        );
        for (final managedLocation in managedLocations.reversed) {
          try {
            await _managedAssetStore.delete(managedLocation);
          } catch (cleanupError, cleanupStackTrace) {
            _logger.warning(
              'Local import cleanup failed: '
              'errorType=${cleanupError.runtimeType}.',
              null,
              cleanupStackTrace,
            );
          }
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

    _logger.info(
      'Local import finished: imported=${imported.length}, '
      'duplicates=${duplicates.length}, unsupported=${unsupported.length}.',
    );

    return LocalPublicationImportResult(
      imported: imported,
      duplicates: duplicates,
      unsupported: unsupported,
    );
  }
}

class PublicationFormatDetector {
  const PublicationFormatDetector._();

  static const supportedExtensions = <String>['cbz', 'epub', 'pdf', 'txt'];

  static PublicationFormat? fromFileName(String fileName) {
    return switch (path.extension(fileName).toLowerCase()) {
      '.cbz' => PublicationFormat.comicArchive,
      '.epub' => PublicationFormat.epub,
      '.pdf' => PublicationFormat.pdf,
      '.txt' => PublicationFormat.text,
      _ => null,
    };
  }

  static String mediaTypeFor(PublicationFormat format) {
    return switch (format) {
      PublicationFormat.comicArchive => 'application/vnd.comicbook+zip',
      PublicationFormat.comicDirectory => 'application/x-comic-directory',
      PublicationFormat.epub => 'application/epub+zip',
      PublicationFormat.pdf => 'application/pdf',
      PublicationFormat.text => 'text/plain',
    };
  }

  static String extensionFor(PublicationFormat format) {
    return switch (format) {
      PublicationFormat.comicArchive => 'cbz',
      PublicationFormat.epub => 'epub',
      PublicationFormat.pdf => 'pdf',
      PublicationFormat.text => 'txt',
      PublicationFormat.comicDirectory => throw ArgumentError.value(
        format,
        'format',
        'is not locally supported',
      ),
    };
  }
}
