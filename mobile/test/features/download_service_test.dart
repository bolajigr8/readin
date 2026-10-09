import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/core/errors/app_exception.dart';
import 'package:readin_flutter/features/library/data/models/book.dart';
import 'package:readin_flutter/features/library/data/services/download_service.dart';

typedef _Reply = ({int status, List<int> body});

class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.handler);

  final _Reply Function(RequestOptions o) handler;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final r = handler(options);
    return ResponseBody.fromBytes(
      Uint8List.fromList(r.body),
      r.status,
      headers: {
        Headers.contentLengthHeader: ['${r.body.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final _epubBytes = <int>[0x50, 0x4B, 0x03, 0x04, ...List.filled(200, 7)];
final _pdfBytes = <int>[...utf8.encode('%PDF-1.7\n'), ...List.filled(200, 9)];
final _htmlBytes = utf8.encode('<html><body>Forbidden</body></html>');

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('readin_dl_'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  DownloadService make(_BytesAdapter adapter) {
    final dio = Dio()..httpClientAdapter = adapter;
    return DownloadService(dio: dio, documentsDir: () async => tmp);
  }

  bool noPartFiles() => tmp
      .listSync(recursive: true)
      .whereType<File>()
      .every((f) => !f.path.endsWith('.part'));

  test('200 + valid EPUB -> books/<id>.epub, no .part left', () async {
    final progress = <double?>[];
    final svc = make(_BytesAdapter((_) => (status: 200, body: _epubBytes)));
    final f = await svc.downloadBook(
      bookId: 'b1',
      url: 'https://x/book.epub',
      format: 'epub',
      onProgress: progress.add,
    );
    expect(f.path, endsWith('${Platform.pathSeparator}books${Platform.pathSeparator}b1.epub'));
    expect(f.existsSync(), isTrue);
    expect(f.lengthSync(), _epubBytes.length);
    expect(noPartFiles(), isTrue);
    expect(progress.last, 1);
    expect(await svc.isDownloaded('b1', 'epub'), isTrue);
    expect(await svc.isDownloaded('b1', 'pdf'), isFalse);
  });

  test('200 + valid PDF', () async {
    final svc = make(_BytesAdapter((_) => (status: 200, body: _pdfBytes)));
    final f = await svc.downloadBook(
      bookId: 'p1', url: 'https://x/a.pdf', format: 'pdf',
    );
    expect(f.path, endsWith('p1.pdf'));
  });

  test('HTML error page saved as 200 is rejected (InvalidFile), nothing kept', () async {
    final svc = make(_BytesAdapter((_) => (status: 200, body: _htmlBytes)));
    await expectLater(
      svc.downloadBook(bookId: 'b2', url: 'https://x/a.epub', format: 'epub'),
      throwsA(isA<InvalidFileException>()),
    );
    expect(await svc.findLocal('b2'), isNull);
    expect(noPartFiles(), isTrue);
  });

  test('EPUB bytes under a PDF request are rejected', () async {
    final svc = make(_BytesAdapter((_) => (status: 200, body: _epubBytes)));
    await expectLater(
      svc.downloadBook(bookId: 'b3', url: 'https://x/a.pdf', format: 'pdf'),
      throwsA(isA<InvalidFileException>()),
    );
  });

  test('401 / 403 -> DownloadBlockedException', () async {
    for (final code in [401, 403]) {
      final svc = make(_BytesAdapter((_) => (status: code, body: _htmlBytes)));
      await expectLater(
        svc.downloadBook(bookId: 'b4', url: 'https://x/a.pdf', format: 'pdf'),
        throwsA(isA<DownloadBlockedException>()),
      );
      expect(await svc.findLocal('b4'), isNull);
      expect(noPartFiles(), isTrue);
    }
  });

  test('404 -> DownloadException with status', () async {
    final svc = make(_BytesAdapter((_) => (status: 404, body: _htmlBytes)));
    await expectLater(
      svc.downloadBook(bookId: 'b5', url: 'https://x/a.epub', format: 'epub'),
      throwsA(isA<DownloadException>().having((e) => e.statusCode, 'status', 404)),
    );
  });

  test('concurrent downloads of the same book share one request', () async {
    final adapter = _BytesAdapter((_) => (status: 200, body: _epubBytes));
    final svc = make(adapter);
    final results = await Future.wait([
      svc.downloadBook(bookId: 'b6', url: 'https://x/a.epub', format: 'epub'),
      svc.downloadBook(bookId: 'b6', url: 'https://x/a.epub', format: 'epub'),
    ]);
    expect(results[0].path, results[1].path);
    expect(adapter.calls, 1);
  });

  test('ensureLocal returns an existing file without network', () async {
    final adapter = _BytesAdapter((_) => (status: 200, body: _epubBytes));
    final svc = make(adapter);
    final book = Book.fromJson({
      '_id': 'b7',
      'title': 'T',
      'originalFormat': 'epub',
      'convertedFileUrl': 'https://x/b.epub',
    });
    await svc.ensureLocal(book);
    expect(adapter.calls, 1);
    await svc.ensureLocal(book);
    expect(adapter.calls, 1); // cached
  });

  test('ensureLocal without a URL throws a clear error', () async {
    final svc = make(_BytesAdapter((_) => (status: 200, body: _epubBytes)));
    await expectLater(
      svc.ensureLocal(Book.fromJson({'_id': 'b8', 'title': 'T'})),
      throwsA(isA<AppException>()),
    );
  });

  test('delete removes the file', () async {
    final svc = make(_BytesAdapter((_) => (status: 200, body: _epubBytes)));
    await svc.downloadBook(bookId: 'b9', url: 'https://x/a.epub', format: 'epub');
    expect(await svc.findLocal('b9'), isNotNull);
    await svc.delete('b9');
    expect(await svc.findLocal('b9'), isNull);
  });

  test('magic bytes helper', () async {
    final e = File('${tmp.path}/e.bin')..writeAsBytesSync(_epubBytes);
    final p = File('${tmp.path}/p.bin')..writeAsBytesSync(_pdfBytes);
    final h = File('${tmp.path}/h.bin')..writeAsBytesSync(_htmlBytes);
    final empty = File('${tmp.path}/z.bin')..writeAsBytesSync(<int>[]);
    expect(await DownloadService.hasValidMagicBytes(e, 'epub'), isTrue);
    expect(await DownloadService.hasValidMagicBytes(e, 'pdf'), isFalse);
    expect(await DownloadService.hasValidMagicBytes(p, 'pdf'), isTrue);
    expect(await DownloadService.hasValidMagicBytes(p, 'epub'), isFalse);
    expect(await DownloadService.hasValidMagicBytes(h, 'epub'), isFalse);
    expect(await DownloadService.hasValidMagicBytes(empty, 'epub'), isFalse);
  });
}
