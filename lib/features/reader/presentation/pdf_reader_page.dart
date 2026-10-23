import 'dart:async';
import 'dart:io';

import 'package:fbooks/app/providers.dart';
import 'package:fbooks/domain/publication/publication.dart';
import 'package:fbooks/domain/publication/publication_asset.dart';
import 'package:fbooks/domain/publication/publication_id.dart';
import 'package:fbooks/domain/reading/reading_locator.dart';
import 'package:fbooks/domain/reading/reading_progress.dart';
import 'package:fbooks/features/reader/presentation/reader_chrome.dart';
import 'package:fbooks/l10n/app_localizations.dart';
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
  final _viewer = PdfViewerController();
  late Future<Publication?> _publication;
  Timer? _pendingSave;
  var _page = 1;
  var _pageCount = 0;

  @override
  void initState() {
    super.initState();
    _publication = ref
        .read(publicationRepositoryProvider)
        .findById(widget.publicationId);
  }

  @override
  void didUpdateWidget(covariant PdfReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.publicationId != widget.publicationId) {
      _pendingSave?.cancel();
      _page = 1;
      _pageCount = 0;
      _publication = ref
          .read(publicationRepositoryProvider)
          .findById(widget.publicationId);
    }
  }

  @override
  void dispose() {
    _pendingSave?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(readingProgressProvider(widget.publicationId));
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      appBar: ReaderToolbar(
        title: widget.title,
        height: MediaQuery.sizeOf(context).width < 600 ? 56 : 64,
        progress: _pageCount > 0 && MediaQuery.sizeOf(context).width >= 600
            ? Text(
                '$_page / $_pageCount',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            : null,
        actions: const [ReaderFullscreenButton()],
      ),
      bottomNavigationBar: _pageCount == 0
          ? null
          : ReaderPageNavigation(
              currentPage: _page,
              pageCount: _pageCount,
              onPageSelected: _goToPage,
              onPrevious: _page > 1 ? () => _goToPage(_page - 1) : null,
              onNext: _page < _pageCount ? () => _goToPage(_page + 1) : null,
            ),
      body: FutureBuilder(
        future: _publication,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              progress.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _PdfReaderError(
              AppLocalizations.of(context)
                  .unableToOpenPublication(snapshot.error.toString()),
            );
          }
          final asset = snapshot.data?.assets
              .where((asset) => asset.kind.isReadableLocalFile)
              .firstOrNull;
          if (asset == null || asset.location.scheme != 'file') {
            return _PdfReaderError(
              AppLocalizations.of(context).localPdfRequired,
            );
          }
          final filePath = asset.location.toFilePath();
          if (!File(filePath).existsSync()) {
            return _PdfReaderError(AppLocalizations.of(context).pdfFileMissing);
          }
          final page = progress.asData?.value?.locator;
          final initialPage = page is PdfPageLocator ? page.pageNumber : 1;
          return PdfViewer.file(
            filePath,
            key: ValueKey(widget.publicationId),
            controller: _viewer,
            initialPageNumber: initialPage,
            params: PdfViewerParams(
              backgroundColor: colors.surfaceContainerLow,
              onPageChanged: _savePage,
              onViewerReady: (document, controller) {
                if (!mounted) return;
                setState(() {
                  _pageCount = document.pages.length;
                  _page = controller.pageNumber ?? initialPage;
                });
              },
            ),
          );
        },
      ),
    );
  }

  void _goToPage(int page) {
    if (_viewer.isReady && page >= 1 && page <= _pageCount) {
      _viewer.goToPage(pageNumber: page);
    }
  }

  void _savePage(int? pageNumber) {
    if (pageNumber == null) return;
    if (mounted) setState(() => _page = pageNumber);
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
