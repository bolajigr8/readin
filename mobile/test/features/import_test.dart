import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/core/errors/app_exception.dart';
import 'package:readin_flutter/features/import/data/import_models.dart';
import 'package:readin_flutter/features/import/data/import_service.dart';
import 'package:readin_flutter/features/library/data/services/download_service.dart';

import '../helpers/test_rig.dart';

final _epub = <int>[0x50, 0x4B, 0x03, 0x04, ...List.filled(300, 1)];
final _pdf = <int>[...utf8.encode('%PDF-1.4\n'), ...List.filled(300, 2)];
final _txt = utf8.encode('just some text pretending to be an epub');

void main() {
  group('title / extension', () {
    test('titleFromFileName mirrors the server', () {
      expect(titleFromFileName('The_Great Gatsby.epub'), 'The Great Gatsby');
      expect(titleFromFileName('my__book___v2.pdf'), 'my book v2');
      expect(titleFromFileName('/storage/emulated/0/Download/Emma.EPUB'), 'Emma');
      expect(titleFromFileName('.pdf'), '.pdf'); // hidden file, no stem
      expect(titleFromFileName('___.pdf'), 'Untitled');
      expect(titleFromFileName('noext'), 'noext');
    });

    test('extensionOf', () {
      expect(extensionOf('A.B.EPUB'), 'epub');
      expect(extensionOf('x.'), '');
      expect(extensionOf('x'), '');
    });
  });

  group('validatePicked (extension + size, never MIME)', () {
    test('accepts pdf / epub case-insensitively', () {
      final a = validatePicked(name: 'a.PDF', path: '/p/a.PDF', size: 10);
      expect(a.ext, 'pdf');
      expect(a.contentType, 'application/pdf');
      final b = validatePicked(name: 'b.EpUb', path: '/p/b', size: 10);
      expect(b.ext, 'epub');
      expect(b.contentType, 'application/epub+zip');
      expect(b.title, 'b');
    });

    test('rejects other types with the RN message', () {
      for (final n in ['a.txt', 'a.docx', 'a.mobi', 'a', 'a.epub.zip']) {
        expect(
          () => validatePicked(name: n, path: '/p', size: 10),
          throwsA(isA<ImportException>().having(
              (e) => e.message, 'message', 'Please choose a PDF or EPUB file.')),
          reason: n,
        );
      }
    });

    test('size limits', () {
      expect(
        () => validatePicked(name: 'a.pdf', path: '/p', size: kMaxImportBytes + 1),
        throwsA(isA<ImportException>()
            .having((e) => e.message, 'm', 'File too large (max 100 MB).')),
      );
      expect(validatePicked(name: 'a.pdf', path: '/p', size: kMaxImportBytes).size,
          kMaxImportBytes);
      expect(
        () => validatePicked(name: 'a.pdf', path: '/p', size: 0),
        throwsA(isA<ImportException>()),
      );
    });
  });

  group('mapUploadError', () {
    test('network / timeout -> offline (offers "read without saving")', () {
      expect(mapUploadError(const NetworkException()).kind, ImportFailureKind.offline);
      expect(mapUploadError(const RequestTimeoutException()).kind,
          ImportFailureKind.offline);
    });
    test('status mapping', () {
      expect(mapUploadError(const ServerException(message: 'x', statusCode: 413)).message,
          'File too large (max 100 MB).');
      expect(mapUploadError(const RateLimitException()).message,
          'Too many uploads. Try again later.');
      final limit = mapUploadError(const ForbiddenException(message: 'Free plan is limited to 10 books.'));
      expect(limit.kind, ImportFailureKind.limitReached);
      expect(limit.message, 'Free plan is limited to 10 books.');
      expect(
        mapUploadError(const ServerException(message: 'Unsupported file type.', statusCode: 400)).message,
        'Unsupported file type.',
      );
    });
  });

  group('ImportService', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('readin_imp_'));
    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    PickedBook picked(String name, List<int> bytes) {
      final f = File('${tmp.path}/$name')..writeAsBytesSync(bytes);
      return PickedBook(
        path: f.path,
        name: name,
        size: bytes.length,
        ext: extensionOf(name),
      );
    }

    DownloadService dl() => DownloadService(
          dio: Dio(),
          documentsDir: () async => Directory('${tmp.path}/docs')..createSync(),
        );

    test('verify: renamed .txt -> .epub is rejected before upload', () async {
      final adapter = FakeAdapter((_) => (status: 201, body: {}));
      final svc = ImportService(api: await makeTestApi(adapter), downloads: dl());
      await expectLater(
        svc.verify(picked('fake.epub', _txt)),
        throwsA(isA<ImportException>().having((e) => e.message, 'm',
            contains('does not look like a valid EPUB'))),
      );
      await svc.verify(picked('real.epub', _epub));
      await svc.verify(picked('real.pdf', _pdf));
      await expectLater(
        svc.verify(picked('epub-as.pdf', _epub)),
        throwsA(isA<ImportException>()),
      );
      expect(adapter.requests, isEmpty);
    });

    test('upload: multipart `file`, filename + content type, auth header', () async {
      final adapter = FakeAdapter((o) => (
            status: 201,
            body: {
              'success': true,
              'message': 'EPUB imported successfully.',
              'data': {'bookId': 'abc123', 'jobId': 'j', 'status': 'ready', 'message': 'ok'},
            },
          ));
      final svc = ImportService(api: await makeTestApi(adapter), downloads: dl());

      final progress = <double>[];
      final res = await svc.upload(
        picked('My_Book.epub', _epub),
        onProgress: progress.add,
      );

      expect(res.isSuccess, isTrue);
      expect(res.dataOrNull!.bookId, 'abc123');
      expect(res.dataOrNull!.status, 'ready');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/files/upload');
      expect(req.headers['Authorization'], 'Bearer tok');
      expect(req.data, isA<FormData>());
      final form = req.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'My_Book.epub');
      expect(form.files.single.value.contentType.toString(),
          contains('application/epub+zip'));
    });

    test('upload: 403 limit and 429 map to typed failures', () async {
      var code = 403;
      final adapter = FakeAdapter((o) => (
            status: code,
            body: {'success': false, 'message': 'Free plan is limited to 10 books.'},
          ));
      final svc = ImportService(api: await makeTestApi(adapter), downloads: dl());
      final r1 = await svc.upload(picked('a.pdf', _pdf));
      expect(mapUploadError(r1.exceptionOrNull!).kind, ImportFailureKind.limitReached);
      code = 429;
      final r2 = await svc.upload(picked('b.pdf', _pdf));
      expect(mapUploadError(r2.exceptionOrNull!).message, 'Too many uploads. Try again later.');
    });

    test('storeLocalCopy -> books/<id>.<ext> and opens offline', () async {
      final adapter = FakeAdapter((_) => (status: 201, body: {}));
      final downloads = dl();
      final svc = ImportService(api: await makeTestApi(adapter), downloads: downloads);
      final f = await svc.storeLocalCopy('book9', picked('x.pdf', _pdf));
      expect(f, isNotNull);
      expect(f!.path, endsWith('books${Platform.pathSeparator}book9.pdf'));
      expect(await downloads.isDownloaded('book9', 'pdf'), isTrue);
      expect(f.lengthSync(), _pdf.length);
      expect(
        Directory('${tmp.path}/docs/books').listSync().whereType<File>().every((e) => !e.path.endsWith('.part')),
        isTrue,
      );
    });

    test('storeLocalCopy never throws (best effort)', () async {
      final adapter = FakeAdapter((_) => (status: 201, body: {}));
      final svc = ImportService(api: await makeTestApi(adapter), downloads: dl());
      final bad = PickedBook(path: '${tmp.path}/missing.pdf', name: 'missing.pdf', size: 5, ext: 'pdf');
      expect(await svc.storeLocalCopy('b', bad), isNull);
    });

    test('saveLocalOnly -> permanent copy with a safe name', () async {
      final adapter = FakeAdapter((_) => (status: 201, body: {}));
      final svc = ImportService(api: await makeTestApi(adapter), downloads: dl());
      final req = await svc.saveLocalOnly(picked('Café Notes (1).epub', _epub));
      expect(File(req.path).existsSync(), isTrue);
      expect(req.path, contains('${Platform.pathSeparator}local${Platform.pathSeparator}'));
      expect(req.path, isNot(contains(' ')));
      expect(req.title, 'Café Notes (1)');
      expect(req.format, 'epub');
    });
  });
}
