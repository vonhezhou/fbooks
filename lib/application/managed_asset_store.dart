import 'dart:typed_data';

/// Stores files owned by Fbooks and removes them by their durable location.
abstract interface class ManagedAssetStore {
  Future<Uri> save({
    required String assetId,
    required String fileName,
    required Stream<Uint8List> bytes,
  });

  Future<void> delete(Uri location);
}
