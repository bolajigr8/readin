import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/features/library/data/models/book.dart';
import 'package:readin_flutter/features/library/utils/library_logic.dart';

Map<String, dynamic> _json({
  required String id,
  String title = 'T',
  String author = '',
  String status = 'ready',
  String created = '2026-01-01T00:00:00.000Z',
  String updated = '2026-01-01T00:00:00.000Z',
  Map<String, dynamic>? progress,
  Map<String, dynamic> extra = const {},
}) =>
    {
      '_id': id,
      'title': title,
      'author': author,
      'status': status,
      'createdAt': created,
      'updatedAt': updated,
      'progress': progress,
      ...extra,
    };

Book _b(Map<String, dynamic> j) => Book.fromJson(j);

void main() {
  group('Book.fromJson (tolerant)', () {
    test('minimal old-server payload', () {
      final b = _b({'_id': 'x', 'title': 'Emma'});
      expect(b.id, 'x');
      expect(b.author, '');
      expect(b.coverUrl, '');
      expect(b.fileSize, 0);
      expect(b.gutenbergId, isNull);
      expect(b.progress, isNull);
      expect(b.hasCover, isFalse);
    });

    test('numbers as strings / ints / doubles', () {
      final b = _b({
        '_id': 'x',
        'fileSize': '2048',
        'progress': {'percentage': 42, 'isCompleted': false},
      });
      expect(b.fileSize, 2048);
      expect(b.progress!.percentage, 42.0);
      expect(b.progress!.lastReadAt, isNull);
    });

    test('format: originalFormat, else URL extension', () {
      expect(_b({'_id': 'a', 'originalFormat': 'PDF'}).format, 'pdf');
      expect(
        _b({
          '_id': 'a',
          'convertedFileUrl': 'https://res.cloudinary.com/x/raw/upload/v1/b.pdf?x=1',
        }).format,
        'pdf',
      );
      expect(
        _b({'_id': 'a', 'originalFileUrl': 'https://x/y/book.EPUB'}).format,
        'epub',
      );
      expect(_b({'_id': 'a'}).format, '');
    });

    test('readableUrl prefers convertedFileUrl', () {
      final b = _b({
        '_id': 'a',
        'originalFileUrl': 'https://o',
        'convertedFileUrl': 'https://c',
      });
      expect(b.readableUrl, 'https://c');
      expect(_b({'_id': 'a', 'originalFileUrl': 'https://o'}).readableUrl, 'https://o');
    });

    test('LibraryResponse', () {
      final r = LibraryResponse.fromJson({
        'books': [_json(id: '1'), _json(id: '2')],
        'meta': {
          'total': 10,
          'page': 1,
          'limit': 50,
          'totalPages': 1,
          'limitReached': true,
        },
      });
      expect(r.books.length, 2);
      expect(r.meta.limitReached, isTrue);
      expect(r.meta.total, 10);
      expect(LibraryResponse.fromJson({}).books, isEmpty);
    });
  });

  group('filter / sort', () {
    final books = [
      _b(_json(id: '1', title: 'Pride and Prejudice', author: 'Jane Austen', created: '2026-01-03T00:00:00Z')),
      _b(_json(id: '2', title: 'dracula', author: 'Bram Stoker', created: '2026-01-01T00:00:00Z')),
      _b(_json(id: '3', title: 'Emma', author: 'Jane Austen', created: '2026-01-02T00:00:00Z',
          progress: {'percentage': 10, 'lastReadAt': '2026-02-01T00:00:00Z', 'isCompleted': false})),
      _b(_json(id: '4', title: 'Hidden', status: 'converting')),
    ];

    test('only ready books; search by title or author, case-insensitive', () {
      expect(filterBooks(books, '').map((b) => b.id), ['1', '2', '3']);
      expect(filterBooks(books, 'AUSTEN').map((b) => b.id), ['1', '3']);
      expect(filterBooks(books, '  drac ').map((b) => b.id), ['2']);
      expect(filterBooks(books, 'zzz'), isEmpty);
    });

    test('sort recent / title / author / lastRead', () {
      final ready = filterBooks(books, '');
      expect(sortBooks(ready, SortKey.recent).map((b) => b.id), ['1', '3', '2']);
      expect(sortBooks(ready, SortKey.title).map((b) => b.id), ['2', '3', '1']);
      // author: Bram Stoker < Jane Austen (stable between the two Austens)
      expect(sortBooks(ready, SortKey.author).map((b) => b.id), ['2', '1', '3']);
      expect(sortBooks(ready, SortKey.lastRead).first.id, '3');
    });
  });

  group('continue reading', () {
    Book p(String id, num pct, {bool done = false, String? read, String status = 'ready'}) =>
        _b(_json(id: id, status: status, progress: {
          'percentage': pct,
          'isCompleted': done,
          'lastReadAt': read,
        }));

    test('0 < % < 99, not completed, ready; latest first; max 3', () {
      final list = [
        p('a', 0),
        p('b', 50, read: '2026-03-01T00:00:00Z'),
        p('c', 99),
        p('d', 30, done: true),
        p('e', 20, read: '2026-03-03T00:00:00Z'),
        p('f', 10, read: '2026-03-02T00:00:00Z'),
        p('g', 5, read: '2026-03-04T00:00:00Z'),
        p('h', 5, status: 'converting', read: '2026-03-09T00:00:00Z'),
        _b(_json(id: 'i')),
      ];
      expect(selectContinueReading(list).map((b) => b.id), ['g', 'e', 'f']);
    });
  });
}
