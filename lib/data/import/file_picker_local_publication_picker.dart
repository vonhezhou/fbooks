import 'package:fbooks/application/library/local_publication_importer.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class FilePickerLocalPublicationPicker implements LocalPublicationPicker {
  @override
  Future<List<LocalPublicationCandidate>> pick() async {
    final initialDirectory = await _initialDirectory();
    final result = await FilePicker.platform.pickFiles(
      initialDirectory: initialDirectory,
      type: FileType.custom,
      allowedExtensions: PublicationFormatDetector.supportedExtensions,
      allowMultiple: true,
    );
    if (result == null) {
      return const [];
    }

    return result.files
        .where((file) => file.path != null)
        .map(
          (file) => LocalPublicationCandidate(
            fileName: file.name,
            location: Uri.file(file.path!),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<LocalPublicationCandidate?> pickReplacement(
    PublicationFormat format,
  ) async {
    final initialDirectory = await _initialDirectory();
    final result = await FilePicker.platform.pickFiles(
      initialDirectory: initialDirectory,
      type: FileType.custom,
      allowedExtensions: [PublicationFormatDetector.extensionFor(format)],
    );
    final file = result?.files.singleOrNull;
    if (file?.path == null) {
      return null;
    }
    return LocalPublicationCandidate(
      fileName: file!.name,
      location: Uri.file(file.path!),
    );
  }

  Future<String?> _initialDirectory() async {
    try {
      return (await getDownloadsDirectory())?.path;
    } catch (_) {
      return null;
    }
  }
}
