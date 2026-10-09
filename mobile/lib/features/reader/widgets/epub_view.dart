import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/reader_models.dart';
import '../data/reader_server.dart';

/// Commands the screen sends to the page (never a reload).
class EpubViewController {
  WebViewController? _web;

  bool get isAttached => _web != null;

  Future<void> _run(String js) async {
    try {
      await _web?.runJavaScript(js);
    } catch (_) {
      // Page not ready / being torn down — commands are best effort.
    }
  }

  void next() => _run('readerApi.next()');
  void prev() => _run('readerApi.prev()');
  void nextSection() => _run('readerApi.nextSection()');
  void prevSection() => _run('readerApi.prevSection()');

  /// `target` = CFI or href.
  void display(String target) => _run('readerApi.display(${jsonEncode(target)})');

  /// Typography / theme (never reloads the page).
  void setTheme(ReaderPrefs p) =>
      _run('readerApi.setTheme(${jsonEncode(jsonEncode(p.toPageJson()))})');

  /// `'paged'` | `'scroll'`.
  void setFlow(String mode) => _run('readerApi.setFlow(${jsonEncode(mode)})');

  /// Jump to a fraction (0–1) of the book (needs locations to be generated).
  void seekPercent(double fraction) => _run('readerApi.seekPercent($fraction)');

  /// Auto-scroll / auto page turn: 0 = off, 1 slow, 2 medium, 3 fast.
  void autoScroll(int level) => _run('readerApi.autoScroll($level)');

  /// Read aloud: asks the page for the sentences of the current chapter
  /// (answer: `onTtsSentences`), highlights one, clears the highlight.
  void ttsPrepare() => _run('readerApi.ttsPrepare()');
  void ttsHighlight(int index) => _run('readerApi.ttsHighlight($index)');
  void ttsClear() => _run('readerApi.ttsClear()');

  /// Full-text search; results arrive through `onSearchResults`.
  void search(String query) => _run('readerApi.search(${jsonEncode(query)})');

  void highlight(String cfiRange, String colorHex, String id) => _run(
        'readerApi.highlight(${jsonEncode(cfiRange)}, ${jsonEncode(colorHex)}, ${jsonEncode(id)})',
      );

  void clearSelection() => _run('readerApi.clearSelection()');

  void removeHighlight(String cfiRange) =>
      _run('readerApi.removeHighlight(${jsonEncode(cfiRange)})');
}

/// EPUB engine: epub.js inside a `WebView`, fed by [ReaderServer].
///
/// All inputs that may change later (font, theme) are NOT constructor
/// arguments that rebuild the page — only initial values are used here and the
/// screen calls [EpubViewController.setTheme]. The widget is therefore stable
/// across page turns and settings changes.
class EpubView extends StatefulWidget {
  const EpubView({
    super.key,
    required this.path,
    required this.controller,
    required this.initialCfi,
    required this.prefs,
    required this.backgroundColor,
    required this.onReady,
    required this.onToc,
    required this.onLocation,
    required this.onTextSelected,
    required this.onTap,
    required this.onAnnotationClicked,
    required this.onLocationsReady,
    required this.onSearchResults,
    required this.onTtsSentences,
    required this.onError,
  });

  final String path;
  final EpubViewController controller;
  final String? initialCfi;
  final ReaderPrefs prefs;
  final Color backgroundColor;

  final VoidCallback onReady;
  final void Function(List<TocItem> toc) onToc;
  final void Function({
    required String cfi,
    required int percentage,
    required int spineIndex,
    required String chapterTitle,
    required String href,
  }) onLocation;
  final void Function(String text, String cfiRange) onTextSelected;
  final VoidCallback onTap;
  final void Function(String annotationId) onAnnotationClicked;
  final VoidCallback onLocationsReady;
  final void Function(String query, List<SearchHit> hits) onSearchResults;
  final void Function(List<String> sentences, int start) onTtsSentences;
  final void Function(String message) onError;

  @override
  State<EpubView> createState() => _EpubViewState();
}

class _EpubViewState extends State<EpubView> {
  ReaderServer? _server;
  WebViewController? _web;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final server = await ReaderServer.start(
        bookFile: File(widget.path),
        config: {
          'initialCfi': widget.initialCfi,
          ...widget.prefs.toPageJson(),
          'flow': widget.prefs.flow,
        },
      );
      if (_disposed) {
        await server.close();
        return;
      }
      _server = server;

      final web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(widget.backgroundColor)
        ..addJavaScriptChannel('ReadIn', onMessageReceived: _onMessage)
        ..setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (e) {
              if (e.isForMainFrame ?? true) {
                widget.onError('Reader page failed to load: ${e.description}');
              }
            },
          ),
        );
      await web.loadRequest(server.pageUrl);
      if (_disposed) return;

      widget.controller._web = web;
      setState(() => _web = web);
    } catch (e) {
      widget.onError('Could not start the reader: $e');
    }
  }

  void _onMessage(JavaScriptMessage m) {
    if (_disposed) return;
    final Map<String, dynamic> d;
    try {
      d = Map<String, dynamic>.from(jsonDecode(m.message) as Map);
    } catch (_) {
      return;
    }
    switch (d['type']) {
      case 'BOOK_READY':
        widget.onReady();
      case 'TOC_READY':
        widget.onToc(parseToc(d['toc']));
      case 'LOCATION':
        widget.onLocation(
          cfi: (d['cfi'] ?? '').toString(),
          percentage: d['percentage'] is num ? (d['percentage'] as num).round() : 0,
          spineIndex: d['chapterIndex'] is num ? (d['chapterIndex'] as num).toInt() : 0,
          chapterTitle: (d['chapterTitle'] ?? '').toString(),
          href: (d['href'] ?? '').toString(),
        );
      case 'TEXT_SELECTED':
        widget.onTextSelected(
          (d['selectedText'] ?? '').toString(),
          (d['cfiRange'] ?? '').toString(),
        );
      case 'TAP':
        widget.onTap();
      case 'LOCATIONS_READY':
        widget.onLocationsReady();
      case 'TTS_SENTENCES':
        final items = d['items'];
        widget.onTtsSentences(
          items is List ? items.map((x) => x.toString()).toList() : const <String>[],
          (d['start'] as num?)?.toInt() ?? 0,
        );
      case 'SEARCH_RESULTS':
        final raw = d['results'];
        widget.onSearchResults(
          (d['query'] ?? '').toString(),
          raw is List
              ? raw
                  .whereType<Map>()
                  .map((x) => SearchHit.fromJson(Map<String, dynamic>.from(x)))
                  .where((h) => h.cfi.isNotEmpty)
                  .toList()
              : const <SearchHit>[],
        );
      case 'ANNOTATION_CLICKED':
        widget.onAnnotationClicked((d['id'] ?? '').toString());
      case 'ERROR':
        widget.onError((d['message'] ?? 'Unknown error').toString());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    widget.controller._web = null;
    final server = _server;
    if (server != null) unawaited(server.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final web = _web;
    if (web == null) {
      return ColoredBox(color: widget.backgroundColor);
    }
    return WebViewWidget(controller: web);
  }
}
