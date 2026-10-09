// NOTE: no TestWidgetsFlutterBinding here — it replaces HttpClient with a mock
// that answers 400, and this test needs real loopback sockets.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/features/reader/data/reader_server.dart';

Future<(int, List<int>, HttpHeaders)> _request(Uri u, {String method = 'GET'}) async {
  final c = HttpClient();
  try {
    final req = await c.openUrl(method, u);
    final res = await req.close();
    final bytes = <int>[];
    await for (final chunk in res) {
      bytes.addAll(chunk);
    }
    return (res.statusCode, bytes, res.headers);
  } finally {
    c.close(force: true);
  }
}

String _text(List<int> b) => String.fromCharCodes(b);

void main() {
  late Directory tmp;
  late File book;
  final bytes = List<int>.generate(70000, (i) => i % 251);
  ReaderServer? server;

  Future<String> assets(String name) async => switch (name) {
        'reader.html' => '<html><script>var CFG = __READIN_CONFIG__;</script></html>',
        _ => '/* $name */',
      };

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('readin_srv_');
    book = File('${tmp.path}/b.epub')..writeAsBytesSync(bytes);
  });

  tearDown(() async {
    await server?.close();
    server = null;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('binds to loopback, serves page with injected config', () async {
    server = await ReaderServer.start(
      bookFile: book,
      config: {'initialCfi': 'epubcfi(/6/4)', 'fontSize': 17, 'theme': 'dark'},
      loadAsset: assets,
    );
    expect(server!.pageUrl.host, '127.0.0.1');
    expect(server!.token.length, 32);

    final (status, body, headers) = await _request(server!.pageUrl);
    expect(status, 200);
    final html = _text(body);
    expect(html, contains('"bookUrl":"book.bin"'));
    expect(html, contains('"initialCfi":"epubcfi(/6/4)"'));
    expect(html, contains('"fontSize":17'));
    expect(html, isNot(contains('__READIN_CONFIG__')));
    expect(headers.contentType?.mimeType, 'text/html');
    expect(headers.value('cache-control'), 'no-store');
  });

  test('config can never close the script block', () async {
    server = await ReaderServer.start(
      bookFile: book,
      config: {'evil': '</script><img src=x>'},
      loadAsset: assets,
    );
    final (_, body, _) = await _request(server!.pageUrl);
    final html = _text(body);
    expect(html, isNot(contains('</script><img')));
    expect(html, contains(r'\u003c/script>'));
  });

  test('streams the whole book byte-for-byte with Content-Length', () async {
    server = await ReaderServer.start(bookFile: book, config: {}, loadAsset: assets);
    final u = server!.pageUrl.replace(path: '/${server!.token}/book.bin');
    final (status, body, headers) = await _request(u);
    expect(status, 200);
    expect(body, bytes);
    expect(headers.contentLength, bytes.length);
  });

  test('serves the two scripts', () async {
    server = await ReaderServer.start(bookFile: book, config: {}, loadAsset: assets);
    for (final n in ['jszip.min.js', 'epub.min.js']) {
      final u = server!.pageUrl.replace(path: '/${server!.token}/$n');
      final (status, body, headers) = await _request(u);
      expect(status, 200);
      expect(_text(body), '/* $n */');
      expect(headers.contentType?.mimeType, 'application/javascript');
    }
  });

  test('wrong token, wrong method and unknown paths are 404', () async {
    server = await ReaderServer.start(bookFile: book, config: {}, loadAsset: assets);
    final base = server!.pageUrl;
    expect((await _request(base.replace(path: '/deadbeef/book.bin'))).$1, 404);
    expect((await _request(base.replace(path: '/book.bin'))).$1, 404);
    expect((await _request(base.replace(path: '/${server!.token}/secret.txt'))).$1, 404);
    expect((await _request(base, method: 'POST')).$1, 404);
  });

  test('missing book file → 404 (not a crash)', () async {
    server = await ReaderServer.start(bookFile: book, config: {}, loadAsset: assets);
    book.deleteSync();
    final u = server!.pageUrl.replace(path: '/${server!.token}/book.bin');
    expect((await _request(u)).$1, 404);
  });

  test('two servers get different ports and tokens; close releases the port', () async {
    final a = await ReaderServer.start(bookFile: book, config: {}, loadAsset: assets);
    final b = await ReaderServer.start(bookFile: book, config: {}, loadAsset: assets);
    expect(a.port, isNot(b.port));
    expect(a.token, isNot(b.token));
    final bUrl = b.pageUrl; // read before closing (port is gone afterwards)
    await b.close();
    await expectLater(_request(bUrl), throwsA(isA<SocketException>()));
    server = a;
  });
}
