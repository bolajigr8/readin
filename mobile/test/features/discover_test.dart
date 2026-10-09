import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/core/api/api_result.dart';
import 'package:readin_flutter/core/errors/app_exception.dart';
import 'package:readin_flutter/features/discover/data/gutenberg_models.dart';
import 'package:readin_flutter/features/discover/data/gutendex_datasource.dart';
import 'package:readin_flutter/features/discover/providers/add_to_library_provider.dart';
import 'package:readin_flutter/features/discover/providers/discover_providers.dart';

Map<String, dynamic> _book(int id, {Map<String, String>? formats}) => {
      'id': id,
      'title': 'Title $id',
      'authors': [
        {'name': 'Austen, Jane', 'birth_year': 1775, 'death_year': 1817},
        {'name': 'Anonymous'},
        {'name': 'Third, Author'},
      ],
      'subjects': ['Love stories', 'England -- Fiction', 'A', 'B', 'C', 'D', 'E'],
      'bookshelves': ['Browsing: Fiction', 'Romance'],
      'languages': ['en'],
      'download_count': 123456,
      'formats': formats ??
          {
            'application/epub+zip': 'https://www.gutenberg.org/ebooks/$id.epub3.images',
            'image/jpeg': 'https://www.gutenberg.org/cache/epub/$id/pg$id.cover.medium.jpg',
          },
    };

class _FakeDs extends GutendexDataSource {
  _FakeDs(this.handler);

  final Future<ApiResult<GutenbergPage>> Function(int page) handler;
  int calls = 0;

  @override
  Future<ApiResult<GutenbergPage>> popular({int page = 1}) {
    calls++;
    return handler(page);
  }
}

GutenbergPage _page(List<int> ids, {bool next = true, int count = 100}) =>
    GutenbergPage(
      count: count,
      hasNext: next,
      results: ids.map((i) => GutenbergBook.fromJson(_book(i))).toList(),
    );

void main() {
  group('Gutendex models + helpers', () {
    test('parse + author formatting', () {
      final b = GutenbergBook.fromJson(_book(1342));
      expect(b.id, 1342);
      expect(b.authors.length, 3);
      expect(formatAuthorName('Austen, Jane'), 'Jane Austen');
      expect(formatAuthorName('Anonymous'), 'Anonymous');
      expect(formatAuthorName('A, B, C'), 'A, B, C'); // not exactly 2 parts
      expect(authorsLine(b, max: 2), 'Jane Austen, Anonymous');
      expect(authorsLine(b), 'Jane Austen, Anonymous, Author Third');
    });

    test('epubUrl prefers epub+zip, falls back, else null', () {
      expect(epubUrl({'application/epub+zip': 'a', 'application/epub': 'b'}), 'a');
      expect(epubUrl({'application/epub': 'b'}), 'b');
      expect(epubUrl({'text/html': 'x'}), isNull);
      expect(epubUrl({'application/epub+zip': ''}), isNull);
    });

    test('coverUrl fallback uses the book id', () {
      expect(coverUrl({'image/jpeg': 'https://x/c.jpg'}, 5), 'https://x/c.jpg');
      expect(
        coverUrl({}, 1342),
        'https://www.gutenberg.org/cache/epub/1342/pg1342.cover.medium.jpg',
      );
    });

    test('downloadsK', () {
      expect(downloadsK(123456), '123k');
      expect(downloadsK(400), '0k');
      expect(downloadsK(1500), '2k');
    });

    test('tolerant parsing of junk', () {
      final b = GutenbergBook.fromJson({'id': '7', 'formats': {'a': null}});
      expect(b.id, 7);
      expect(b.title, '');
      expect(b.authors, isEmpty);
      expect(b.formats, isEmpty);
      expect(GutenbergPage.fromJson({}).results, isEmpty);
    });
  });

  group('POST /library/discover body', () {
    test('matches the server schema', () {
      final body = discoverBody(GutenbergBook.fromJson(_book(1342)));
      expect(body['gutenbergId'], '1342'); // string
      expect(body['author'], 'Jane Austen, Anonymous, Author Third');
      expect(body['description'], 'Love stories. England -- Fiction. A');
      expect(body['epubUrl'], startsWith('https://'));
      expect(body['coverUrl'], contains('pg1342'));
      expect(body['language'], 'en');
      expect(body['genre'], 'Fiction'); // "Browsing: " prefix stripped
      expect(body.keys.toSet(), {
        'gutenbergId', 'title', 'author', 'description',
        'coverUrl', 'epubUrl', 'language', 'genre',
      });
    });
  });

  group('DiscoverFeedNotifier (paging)', () {
    test('loadFirst, loadMore (dedupe), exhausted', () async {
      final ds = _FakeDs((page) async => switch (page) {
            1 => Success(_page([1, 2, 3])),
            2 => Success(_page([3, 4], next: false)), // 3 repeated
            _ => Success(_page([])),
          });
      final n = DiscoverFeedNotifier(ds, const DiscoverQuery.popular());
      await Future<void>.delayed(Duration.zero);
      expect(n.state.isLoading, isFalse);
      expect(n.state.books.map((b) => b.id), [1, 2, 3]);
      expect(n.state.nextPage, 2);

      await n.loadMore();
      expect(n.state.books.map((b) => b.id), [1, 2, 3, 4]);
      expect(n.state.hasNext, isFalse);

      final calls = ds.calls;
      await n.loadMore(); // exhausted -> no-op
      expect(ds.calls, calls);
      n.dispose();
    });

    test('first-page error then retry', () async {
      var fail = true;
      final ds = _FakeDs((page) async => fail
          ? const Failure(NetworkException())
          : Success(_page([1], next: false)));
      final n = DiscoverFeedNotifier(ds, const DiscoverQuery.popular());
      await Future<void>.delayed(Duration.zero);
      expect(n.state.error, isA<NetworkException>());
      expect(n.state.isLoading, isFalse);

      fail = false;
      await n.loadFirst();
      expect(n.state.error, isNull);
      expect(n.state.books.length, 1);
      n.dispose();
    });

    test('a failed next page does not retry on its own', () async {
      var failNext = true;
      final ds = _FakeDs((page) async {
        if (page == 1) return Success(_page([1, 2]));
        return failNext
            ? const Failure(NetworkException())
            : Success(_page([3], next: false));
      });
      final n = DiscoverFeedNotifier(ds, const DiscoverQuery.popular());
      await Future<void>.delayed(Duration.zero);

      await n.loadMore();
      expect(n.state.nextError, isNotNull);
      expect(n.state.books.length, 2); // list kept

      final calls = ds.calls;
      await n.loadMore(); // scroll event: must NOT hit the network again
      expect(ds.calls, calls);

      failNext = false;
      await n.loadMore(retry: true);
      expect(n.state.books.length, 3);
      expect(n.state.nextError, isNull);
      n.dispose();
    });
  });

  test('DiscoverQuery value equality (provider family key)', () {
    expect(const DiscoverQuery(DiscoverKind.search, 'a'),
        const DiscoverQuery(DiscoverKind.search, 'a'));
    expect(const DiscoverQuery(DiscoverKind.search, 'a') ==
        const DiscoverQuery(DiscoverKind.category, 'a'), isFalse);
    expect(const DiscoverQuery.popular().hashCode,
        const DiscoverQuery.popular().hashCode);
  });
}
