import 'dart:typed_data';

import 'package:fbooks/application/opds/opds_acquisition_importer.dart';
import 'package:fbooks/application/opds/opds_credentials.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final _logger = Logger('opds.download');

class HttpRemoteAssetFetcher implements RemoteAssetFetcher {
  HttpRemoteAssetFetcher(this._client);

  final http.Client _client;

  @override
  Future<RemoteAssetResponse> fetch(
    Uri uri, {
    OpdsCredentials? credentials,
  }) async {
    _logger.info('OPDS download request started.');
    try {
      final request = http.Request('GET', uri);
      if (credentials != null) {
        request.headers['Authorization'] = credentials.authorizationHeader;
      }
      final response = await _client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _logger.warning(
          'OPDS download request returned status=${response.statusCode}.',
        );
        throw http.ClientException(
          'Download returned ${response.statusCode}',
          uri,
        );
      }

      _logger.info('OPDS download request accepted.');
      return RemoteAssetResponse(
        bytes: response.stream.map(Uint8List.fromList),
        fileName: _fileName(response.headers['content-disposition'], uri),
        mediaType: response.headers['content-type']?.split(';').first.trim(),
        contentLength: int.tryParse(response.headers['content-length'] ?? ''),
      );
    } catch (error, stackTrace) {
      _logger.severe(
        'OPDS download request failed: errorType=${error.runtimeType}.',
        null,
        stackTrace,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  String _fileName(String? contentDisposition, Uri uri) {
    final match = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(contentDisposition ?? '');
    return match?.group(1) ?? path.basename(uri.path);
  }
}
