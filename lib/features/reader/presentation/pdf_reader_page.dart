import 'dart:async';
import 'dart:io';

import 'package:fbooks/app/providers.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfReaderPage extends ConsumerStatefulWidget {
  const PdfReaderPage({
    super.key,
    required this.publicationId,
    required this.title,
  });

  final PublicationId publicationId;
  final String title;

  @override
  ConsumerState<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends ConsumerState<PdfReaderPage> {
  Timer? _pendingSave;

  @override
  void dispose() {
    _pendingSave?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final publication = ref.watch(publicationRepositoryProvider);
    final progress = ref.watch(readingProgressProvider(widget.publicationId));
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder(
        future: publication.findById(widget.publicationId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final asset = snapshot.data?.assets
              .where((asset) => asset.kind == PublicationAssetKind.localFile)
              .firstOrNull;
          if (asset == null || asset.location.scheme != 'file') {
            return const _PdfReaderError('A local PDF file is required.');
          }
          final filePath = asset.location.toFilePath();
          if (!File(filePath).existsSync()) {
            return const _PdfReaderError('The imported PDF file is missing.');
          }
          final page = progress.asData?.value?.locator;
          final initialPage = page is PdfPageLocator ? page.pageNumber : 1;
          return PdfViewer.file(
            filePath,
            initialPageNumber: initialPage,
            params: PdfViewerParams(onPageChanged: _savePage),
          );
        },
      ),
    );
  }

  void _savePage(int? pageNumber) {
    if (pageNumber == null) return;
    _pendingSave?.cancel();
    _pendingSave = Timer(const Duration(milliseconds: 400), () async {
      final repository = ref.read(readingProgressRepositoryProvider);
      await repository.save(
        ReadingProgress(
          publicationId: widget.publicationId,
          locator: PdfPageLocator(pageNumber),
          updatedAt: DateTime.now(),
        ),
      );
    });
  }
}

class _PdfReaderError extends StatelessWidget {
  const _PdfReaderError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
  );
}
