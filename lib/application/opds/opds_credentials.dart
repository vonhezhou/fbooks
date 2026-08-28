import 'dart:convert';

/// Basic credentials supplied by an OPDS catalog owner.
class OpdsCredentials {
  const OpdsCredentials({required this.username, required this.password});

  final String username;
  final String password;

  String get authorizationHeader =>
      'Basic ${base64.encode(utf8.encode('$username:$password'))}';
}
