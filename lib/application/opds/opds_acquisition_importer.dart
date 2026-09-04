import 'dart:typed_data';

import 'package:fbooks/application/managed_asset_store.dart';
import 'package:fbooks/application/library/local_publication_importer.dart';
import 'package:fbooks/application/opds/opds_catalog.dart';
import 'package:fbooks/application/opds/opds_credentials.dart';
import 'package:fbooks/application/opds/opds_credentials_repository.dart';
import 'package:fbooks/domain/library/library_source.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_repository.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

final _logger = Logger('opds.acquisition');

class RemoteAssetResponse {
  const RemoteAssetResponse({
    required this.bytes,
    required this.fileName,
    this.mediaType,
    this.contentLength,
  });

  final Stream<Uint8List> bytes;
  final String fileName;
  final String? mediaType;
  final int? contentLength;
}

class OpdsDownloadProgress {
  const OpdsDownloadProgress({required this.receivedBytes, this.totalBytes});

  final int receivedBytes;
  final int? totalBytes;

  double? get fraction => totalBytes == null || totalBytes == 0
      ? null
      : receivedBytes / totalBytes!;
}

class OpdsDownloadCancellation {
  var _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() => _isCancelled = true;
}

class OpdsDownloadCancelled implements Exception {
  const OpdsDownloadCancelled();
}

abstract interface class RemoteAssetFetcher {
  Future<RemoteAssetResponse> fetch(Uri uri, {OpdsCredentials? credentials});
}

class OpdsAcquisitionImporter {
  OpdsAcquisitionImporter(
    this._publicationRepository,
    this._remoteAssetFetcher,
    this._managedAssetStore, {
    required this._credentialsRepository,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final PublicationRepository _publicationRepository;
  final RemoteAssetFetcher _remoteAssetFetcher;
  final ManagedAssetStore _managedAssetStore;
  final OpdsCredentialsRepository _credentialsRepository;
  final Uuid _uuid;

  Future<Publication> acquire({
    required LibrarySource source,
    required OpdsPublication publication,
    required OpdsAcquisition acquisition,
    void Function(OpdsDownloadProgress progress)? onProgress,
    OpdsDownloadCancellation? cancellation,
  }) async {
    final existing = await _publicationRepository.findByAssetLocation(
      acquisition.href,
    );
    if (existing != null) {
      _logger.info('OPDS acquisition refreshed existing metadata.');
      return _refreshMetadata(existing, source, publication);
    }

    final format = _detectFormat(acquisition);
    if (format == null) {
      throw UnsupportedError(
        'Unsupported OPDS acquisition: ${acquisition.href}',
      );
    }
    _logger.info('OPDS acquisition started: format=${format.name}.');

    final publicationId = _uuid.v4();
    final remoteAssetId = _uuid.v4();
    final localAssetId = _uuid.v4();
    final credentials = await _credentialsRepository.load(source.id);
    final response = await _remoteAssetFetcher.fetch(
      acquisition.href,
      credentials: credentials,
    );
    Uri? localLocation;
    try {
      localLocation = await _managedAssetStore.save(
        assetId: localAssetId,
        fileName: _safeFileName(response.fileName, acquisition.href),
        bytes: _reportProgress(
          response.bytes,
          totalBytes: response.contentLength,
          onProgress: onProgress,
          cancellation: cancellation,
        ),
      );
      final acquired = Publication(
        id: publicationId,
        source: source,
        title: publication.title,
        authors: publication.authors,
        format: format,
        description: publication.description,
        coverUri: publication.coverUri,
        publishedAt: publication.publishedAt,
        tags: publication.tags,
        assets: [
          PublicationAsset(
            id: remoteAssetId,
            publicationId: publicationId,
            kind: PublicationAssetKind.remoteAcquisition,
            location: acquisition.href,
            mediaType: acquisition.mediaType,
          ),
          PublicationAsset(
            id: localAssetId,
            publicationId: publicationId,
            kind: PublicationAssetKind.managedFile,
            location: localLocation,
            mediaType: response.mediaType ?? acquisition.mediaType,
          ),
        ],
      );
      await _publicationRepository.save(acquired);
      _logger.info('OPDS acquisition completed: format=${format.name}.');
      return acquired;
    } catch (error, stackTrace) {
      _logger.severe(
        'OPDS acquisition failed: errorType=${error.runtimeType}.',
        null,
        stackTrace,
      );
      if (localLocation != null) {
        try {
          await _managedAssetStore.delete(localLocation);
        } catch (cleanupError, cleanupStackTrace) {
          _logger.warning(
            'OPDS acquisition cleanup failed: '
            'errorType=${cleanupError.runtimeType}.',
            null,
            cleanupStackTrace,
          );
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<Publication> _refreshMetadata(
    Publication existing,
    LibrarySource source,
    OpdsPublication remote,
  ) async {
    final refreshed = Publication(
      id: existing.id,
      source: source,
      title: remote.title,
      authors: remote.authors,
      format: existing.format,
      description: remote.description,
      coverUri: remote.coverUri,
      publishedAt: remote.publishedAt,
      tags: remote.tags,
      assets: existing.assets,
    );
    await _publicationRepository.save(refreshed);
    return refreshed;
  }

  Stream<Uint8List> _reportProgress(
    Stream<Uint8List> bytes, {
    required int? totalBytes,
    required void Function(OpdsDownloadProgress progress)? onProgress,
    required OpdsDownloadCancellation? cancellation,
  }) async* {
    var receivedBytes = 0;
    await for (final chunk in bytes) {
      if (cancellation?.isCancelled ?? false) {
        _logger.info('OPDS acquisition cancelled.');
        throw const OpdsDownloadCancelled();
      }
      receivedBytes += chunk.length;
      onProgress?.call(
        OpdsDownloadProgress(
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
        ),
      );
      yield chunk;
    }
    if (cancellation?.isCancelled ?? false) {
      _logger.info('OPDS acquisition cancelled.');
      throw const OpdsDownloadCancelled();
    }
  }

  PublicationFormat? _detectFormat(OpdsAcquisition acquisition) {
    final fromFileName = PublicationFormatDetector.fromFileName(
      acquisition.href.path,
    );
    if (fromFileName != null) {
      return fromFileName;
    }
    return switch (acquisition.mediaType?.toLowerCase()) {
      'application/vnd.comicbook+zip' => PublicationFormat.comicArchive,
      'application/epub+zip' => PublicationFormat.epub,
      'application/pdf' => PublicationFormat.pdf,
      'text/plain' => PublicationFormat.text,
      _ => null,
    };
  }

  String _safeFileName(String fileName, Uri source) {
    final candidate = fileName.trim().isEmpty
        ? path.basename(source.path)
        : path.basename(fileName);
    return candidate.isEmpty ? 'download' : candidate;
  }
}
