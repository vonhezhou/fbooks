import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

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
  LocalPublicationImporter(this._repository, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const _localSource = LibrarySource(
    id: 'local-library',
    kind: LibrarySourceKind.local,
    name: 'Local library',
  );

  final PublicationRepository _repository;
  final Uuid _uuid;

  Future<LocalPublicationImportResult> importCandidates(
    List<LocalPublicationCandidate> candidates,
  ) async {
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
      final publication = Publication(
        id: publicationId,
        source: _localSource,
        title: path.basenameWithoutExtension(candidate.fileName),
        format: format,
        assets: [
          PublicationAsset(
            id: _uuid.v4(),
            publicationId: publicationId,
            kind: PublicationAssetKind.localFile,
            location: candidate.location,
            mediaType: PublicationFormatDetector.mediaTypeFor(format),
          ),
        ],
      );
      await _repository.save(publication);
      imported.add(publication);
    }

    return LocalPublicationImportResult(
      imported: imported,
      duplicates: duplicates,
      unsupported: unsupported,
    );
  }
}

class PublicationFormatDetector {
  const PublicationFormatDetector._();

  static const supportedExtensions = <String>['cbz', 'epub', 'txt'];

  static PublicationFormat? fromFileName(String fileName) {
    return switch (path.extension(fileName).toLowerCase()) {
      '.cbz' => PublicationFormat.comicArchive,
      '.epub' => PublicationFormat.epub,
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
      PublicationFormat.text => 'txt',
      PublicationFormat.comicDirectory || PublicationFormat.pdf =>
        throw ArgumentError.value(format, 'format', 'is not locally supported'),
    };
  }
}
