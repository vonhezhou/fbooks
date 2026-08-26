import 'package:fbooks/application/library/local_publication_importer.dart';
import 'package:file_picker/file_picker.dart';

class FilePickerLocalPublicationPicker implements LocalPublicationPicker {
  @override
  Future<List<LocalPublicationCandidate>> pick() async {
    final result = await FilePicker.platform.pickFiles(
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
}
