import 'dart:io';
import 'dart:typed_data';

import 'package:fbooks/application/opds/opds_acquisition_importer.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final _logger = Logger('storage.managed_assets');

class AppSupportManagedAssetStore implements ManagedAssetStore {
  @override
  Future<void> delete(Uri location) async {
    if (location.scheme != 'file') {
      return;
    }
    final file = File.fromUri(location);
    if (await file.exists()) {
      await file.delete();
      _logger.info('Managed asset deleted.');
    }
  }

  @override
  Future<Uri> save({
    required String assetId,
    required String fileName,
    required Stream<Uint8List> bytes,
  }) async {
    final appSupportDirectory = await getApplicationSupportDirectory();
    final libraryDirectory = Directory(
      path.join(appSupportDirectory.path, 'fbooks', 'library'),
    );
    await libraryDirectory.create(recursive: true);

    final extension = path.extension(fileName);
    final target = File(path.join(libraryDirectory.path, '$assetId$extension'));
    final temporary = File('${target.path}.part');
    final sink = temporary.openWrite();
    var sinkClosed = false;
    try {
      await for (final chunk in bytes) {
        sink.add(chunk);
      }
      await sink.close();
      sinkClosed = true;
      if (await target.exists()) {
        await target.delete();
      }
      await temporary.rename(target.path);
      _logger.info('Managed asset saved.');
      return target.uri;
    } catch (_) {
      if (!sinkClosed) {
        await sink.close();
      }
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
  }
}
