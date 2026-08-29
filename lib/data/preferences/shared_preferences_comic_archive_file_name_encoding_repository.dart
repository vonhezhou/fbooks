import 'dart:convert';

import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/comic_archive_file_name_encoding_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesComicArchiveFileNameEncodingRepository
    implements ComicArchiveFileNameEncodingRepository {
  static const _storageKey = 'comic-archive-file-name-encodings';

  @override
  Future<String?> load(PublicationId publicationId) async {
    final values = await _readValues();
    return values[publicationId];
  }

  @override
  Future<void> save(PublicationId publicationId, String? encodingName) async {
    final preferences = await SharedPreferences.getInstance();
    final values = await _readValues(preferences);
    if (encodingName == null) {
      values.remove(publicationId);
    } else {
      values[publicationId] = encodingName;
    }
    await preferences.setString(_storageKey, jsonEncode(values));
  }

  @override
  Future<void> delete(PublicationId publicationId) => save(publicationId, null);

  Future<Map<String, String>> _readValues([
    SharedPreferences? existingPreferences,
  ]) async {
    final preferences =
        existingPreferences ?? await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null) {
      return {};
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<Object?, Object?>) {
        return {};
      }
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } on FormatException {
      return {};
    }
  }
}
