import 'package:fbooks/data/preferences/shared_preferences_comic_archive_file_name_encoding_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'persists and clears a per-publication archive encoding override',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository =
          SharedPreferencesComicArchiveFileNameEncodingRepository();

      await repository.save('comic-1', 'gbk');
      expect(await repository.load('comic-1'), 'gbk');

      await repository.delete('comic-1');
      expect(await repository.load('comic-1'), isNull);
    },
  );
}
