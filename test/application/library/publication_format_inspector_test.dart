import 'package:fbooks/application/library/publication_format_inspector.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routes an inspection to the matching format adapter', () async {
    final inspector = _RecordingInspector();
    final registry = PublicationInspectorRegistry([inspector]);

    final result = await registry.inspect(
      format: PublicationFormat.epub,
      location: Uri.file('/managed/book.epub'),
    );

    expect(inspector.inspected, isTrue);
    expect(result?.metadata?.title, 'Embedded title');
    expect(registry.supports(PublicationFormat.pdf), isFalse);
  });
}

class _RecordingInspector implements PublicationFormatInspector {
  var inspected = false;

  @override
  bool supports(PublicationFormat format) => format == PublicationFormat.epub;

  @override
  Future<PublicationInspection?> inspect({
    required PublicationFormat format,
    required Uri location,
  }) async {
    inspected = true;
    return const PublicationInspection(
      metadata: PublicationMetadataPatch(title: 'Embedded title'),
    );
  }
}
