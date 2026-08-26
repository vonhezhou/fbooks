import 'package:fbooks/domain/reading/comic_document.dart';
import 'package:path/path.dart' as path;

class ComicPageIndex {
  const ComicPageIndex._();

  static List<ComicPageDescriptor> fromEntryNames(Iterable<String> entryNames) {
    final imageNames = entryNames.where(_isImageName).toList()
      ..sort(_naturalCompare);
    return [
      for (var index = 0; index < imageNames.length; index++)
        ComicPageDescriptor(index: index, name: imageNames[index]),
    ];
  }

  static bool _isImageName(String entryName) {
    return switch (path.extension(entryName).toLowerCase()) {
      '.avif' ||
      '.bmp' ||
      '.gif' ||
      '.jpeg' ||
      '.jpg' ||
      '.png' ||
      '.webp' => true,
      _ => false,
    };
  }

  static int _naturalCompare(String left, String right) {
    final leftParts = _parts(left);
    final rightParts = _parts(right);
    final length = leftParts.length < rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var index = 0; index < length; index++) {
      final leftPart = leftParts[index];
      final rightPart = rightParts[index];
      final leftNumber = int.tryParse(leftPart);
      final rightNumber = int.tryParse(rightPart);
      final comparison = leftNumber != null && rightNumber != null
          ? leftNumber.compareTo(rightNumber)
          : leftPart.toLowerCase().compareTo(rightPart.toLowerCase());
      if (comparison != 0) {
        return comparison;
      }
    }
    return leftParts.length.compareTo(rightParts.length);
  }

  static List<String> _parts(String value) {
    return RegExp(r'\d+|\D+')
        .allMatches(value)
        .map((match) => match.group(0)!)
        .toList();
  }
}
