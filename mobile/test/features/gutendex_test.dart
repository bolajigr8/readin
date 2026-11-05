import 'dart:io' show HandshakeException;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/core/api/api_result.dart';
import 'package:readin_flutter/core/errors/app_exception.dart';
import 'package:readin_flutter/features/discover/data/gutendex_datasource.dart';

import '../helpers/test_rig.dart';

class _MemCache implements GutendexCache {
  final Map<String, String> m = {};
  @override
  String? read(String key) => m[key];
  @override
  Future<void> write(String key, String value) async => m[key] = value;
}

Map<String, Object?> _page(String title, {bool next = true}) => {
      'count': 1,
      'next': next ? 'https://gutendex.com/books/?page=2' : null,
      'results': [
        {
          'id': 84,
          'title': title,
          'authors': [
            {'name': 'Shelley, Mary Wollstonecraft'},
          ],
          'subjects': <String>[],
          'bookshelves': <String>[],
          'languages': ['en'],
          'download_count': 1234,
          'formats': {'application/epub+zip': 'https://www.gutenberg.org/ebooks/84.epub.images'},
        },
      ],
    };

TestReply _ok(Object body) => (status: 200, body: body);

void main() {
  GutendexDataSource make(FakeAdapter a, {GutendexCache? cache}) => GutendexDataSource(
        dio: Dio(BaseOptions(baseUrl: 'https://gutendex.com'))..httpClientAdapter = a,
        cache: cache,
        retryDelay: Duration.zero,
      );

  test('a slow/failing Gutendex is retried and then succeeds', () async {
    var n = 0;
    final a = FakeAdapter((o) {
      n++;
      return n < 3 ? (status: 503, body: {'detail': 'busy'}) : _ok(_page('Frankenstein'));
    });
    final r = await make(a).popular();
    expect(r, isA<Success<dynamic>>());
    expect(r.dataOrNull!.results.single.title, 'Frankenstein');
    expect(a.requests.length, 3);
  });

  test('a 404 is not retried', () async {
    final a = FakeAdapter((o) => (status: 404, body: {'detail': 'Not found.'}));
    final r = await make(a).byId(999999999);
    expect(r.exceptionOrNull, isA<NotFoundException>());
    expect(a.requests.length, 1);
  });

  test('timeouts give a clear message after 3 attempts', () async {
    final a = FakeAdapter((o) => throw DioException(requestOptions: o, type: DioExceptionType.receiveTimeout));
    final r = await make(a).popular();
    final e = r.exceptionOrNull;
    expect(e, isA<RequestTimeoutException>());
    expect(e!.message, contains('slow or not answering'));
    expect(a.requests.length, 3);
  });

  test('no connection → NetworkException', () async {
    final a = FakeAdapter((o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError));
    final r = await make(a).search('austen');
    expect(r.exceptionOrNull, isA<NetworkException>());
  });

  test('a failed TLS handshake is explained (date/time, Wi-Fi login)', () async {
    final a = FakeAdapter((o) => throw DioException(
          requestOptions: o,
          type: DioExceptionType.unknown,
          error: const HandshakeException('bad certificate'),
        ));
    final r = await make(a).popular();
    expect(r.exceptionOrNull!.message, contains('secure connection'));
  });

  test('when Gutenberg is down the last good first page is shown (and flagged)', () async {
    final cache = _MemCache();
    var down = false;
    final a = FakeAdapter((o) {
      if (down) throw DioException(requestOptions: o, type: DioExceptionType.connectionTimeout);
      return _ok(_page('Pride and Prejudice'));
    });
    final ds = make(a, cache: cache);

    final first = await ds.popular();
    expect(first.dataOrNull!.fromCache, isFalse);
    expect(cache.m, isNotEmpty);

    down = true;
    final again = await ds.popular();
    expect(again.dataOrNull!.fromCache, isTrue);
    expect(again.dataOrNull!.results.single.title, 'Pride and Prejudice');

    // later pages and other lists have no saved copy → a real error
    final page2 = await ds.popular(page: 2);
    expect(page2.exceptionOrNull, isA<RequestTimeoutException>());
    final other = await ds.search('dracula');
    expect(other.exceptionOrNull, isA<RequestTimeoutException>());
  });
}
