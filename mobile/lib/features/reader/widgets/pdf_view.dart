import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// PDF engine (pdfrx). Only the minimal, stable pdfrx API is used:
/// `PdfViewer.file`, `PdfViewerController.goToPage / pageCount`,
/// `PdfViewerParams.onViewerReady / onPageChanged / backgroundColor`.
class PdfReaderView extends StatefulWidget {
  const PdfReaderView({
    super.key,
    required this.path,
    required this.controller,
    required this.initialPage,
    required this.backgroundColor,
    required this.onReady,
    required this.onPage,
    required this.onError,
  });

  final String path;
  final PdfViewerController controller;

  /// 1-based page to restore (null/1 = start).
  final int? initialPage;
  final Color backgroundColor;
  final void Function(int pages) onReady;
  final void Function(int page, int pages) onPage;
  final void Function(String message) onError;

  @override
  State<PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends State<PdfReaderView> {
  Timer? _watchdog;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // pdfrx renders its own error text for corrupt / encrypted files and gives
    // no hook, so a file that never becomes ready is reported after 20 s.
    _watchdog = Timer(const Duration(seconds: 20), () {
      if (!_ready && mounted) {
        widget.onError(
          'Could not open this PDF. It may be corrupted or password-protected.',
        );
      }
    });
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PdfViewer.file(
      widget.path,
      controller: widget.controller,
      params: PdfViewerParams(
        backgroundColor: widget.backgroundColor,
        onViewerReady: (document, controller) {
          _ready = true;
          _watchdog?.cancel();
          final pages = document.pages.length;
          widget.onReady(pages);
          final start = widget.initialPage;
          if (start != null && start > 1 && start <= pages) {
            controller.goToPage(pageNumber: start);
          }
        },
        onPageChanged: (pageNumber) {
          if (pageNumber == null || !_ready) return;
          widget.onPage(pageNumber, widget.controller.pageCount);
        },
      ),
    );
  }
}
