import 'package:fbooks/application/opds/opds_credentials.dart';

/// Persists OPDS credentials outside the regular library database.
abstract interface class OpdsCredentialsRepository {
  Future<OpdsCredentials?> load(String sourceId);

  Future<void> save(String sourceId, OpdsCredentials credentials);

  Future<void> delete(String sourceId);
}
