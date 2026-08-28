import 'dart:convert';

import 'package:fbooks/application/opds/opds_credentials.dart';
import 'package:fbooks/application/opds/opds_credentials_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureOpdsCredentialsRepository implements OpdsCredentialsRepository {
  SecureOpdsCredentialsRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String sourceId) async {
    await _storage.delete(key: _usernameKey(sourceId));
    await _storage.delete(key: _passwordKey(sourceId));
  }

  @override
  Future<OpdsCredentials?> load(String sourceId) async {
    final username = await _storage.read(key: _usernameKey(sourceId));
    final password = await _storage.read(key: _passwordKey(sourceId));
    if (username == null || password == null) {
      return null;
    }
    return OpdsCredentials(username: username, password: password);
  }

  @override
  Future<void> save(String sourceId, OpdsCredentials credentials) async {
    await _storage.write(
      key: _usernameKey(sourceId),
      value: credentials.username,
    );
    await _storage.write(
      key: _passwordKey(sourceId),
      value: credentials.password,
    );
  }

  String _usernameKey(String sourceId) =>
      'fbooks.opds.${_keyPart(sourceId)}.username';

  String _passwordKey(String sourceId) =>
      'fbooks.opds.${_keyPart(sourceId)}.password';

  String _keyPart(String sourceId) => base64Url.encode(utf8.encode(sourceId));
}
