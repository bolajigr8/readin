import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

/// Tiny HTTP server bound to **127.0.0.1** that feeds the EPUB reader page.
///
/// Why: epub.js needs the page, its two scripts and the book on one origin.
/// `file://` pages cannot XHR other files, and base64-ing a 40 MB book into a
/// JS string is slow and memory hungry (the RN reader's failure modes). The
/// book is streamed from disk, never read into Dart memory.
///
/// Every URL starts with a random per-session token, so other apps on the
/// phone cannot read the book through the loopback port.
class ReaderServer {
  ReaderServer._(this._server, this.token, this._book, this._config, this._assets);

  final HttpServer _server;
  final String token;
  final File _book;
  final Map<String, dynamic> _config;
  final Future<String> Function(String assetName) _assets;

  /// The page the WebView loads.
  Uri get pageUrl =>
      Uri.parse('http://127.0.0.1:${_server.port}/$token/reader.html');

  /// The document viewer page (Word, Excel, text, comics…).
  Uri get viewerUrl =>
      Uri.parse('http://127.0.0.1:${_server.port}/$token/viewer.html');

  int get port => _server.port;

  /// Starts the server. [config] is injected into `reader.html`
  /// (`bookUrl` is added automatically). [loadAsset] defaults to the app bundle.
  static Future<ReaderServer> start({
    required File bookFile,
    required Map<String, dynamic> config,
    Future<String> Function(String assetName)? loadAsset,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final rnd = Random.secure();
    final token =
        List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join();

    final s = ReaderServer._(
      server,
      token,
      bookFile,
      {...config, 'bookUrl': 'book.bin'},
      loadAsset ?? (name) => rootBundle.loadString('assets/reader/$name'),
    );
    server.listen(s._handle, onError: (_) {});
    return s;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final segs = req.uri.pathSegments;
      if (req.method != 'GET' || segs.length != 2 || segs[0] != token) {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }

      res.headers.set('Cache-Control', 'no-store');

      switch (segs[1]) {
        case 'reader.html':
        case 'viewer.html':
          final html = await _assets(segs[1]);
          // `<` is escaped so no value can ever close the <script> block.
          final cfg = jsonEncode(_config).replaceAll('<', r'\u003c');
          res.headers.contentType = ContentType.html;
          res.write(html.replaceFirst('__READIN_CONFIG__', cfg));
          await res.close();
        case 'jszip.min.js':
        case 'epub.min.js':
        case 'viewer_core.js':
          res.headers.contentType =
              ContentType('application', 'javascript', charset: 'utf-8');
          res.write(await _assets(segs[1]));
          await res.close();
        case 'book.bin':
          if (!await _book.exists()) {
            res.statusCode = HttpStatus.notFound;
            await res.close();
            return;
          }
          res.headers.contentType = ContentType.binary;
          res.contentLength = await _book.length();
          await res.addStream(_book.openRead());
          await res.close();
        default:
          res.statusCode = HttpStatus.notFound;
          await res.close();
      }
    } catch (_) {
      try {
        res.statusCode = HttpStatus.internalServerError;
        await res.close();
      } catch (_) {
        // client already gone
      }
    }
  }

  Future<void> close() => _server.close(force: true);
}
