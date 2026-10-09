import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/features/annotations/data/annotation_models.dart';
import 'package:readin_flutter/features/annotations/data/annotations_repository.dart';
import 'package:readin_flutter/features/annotations/providers/annotations_providers.dart';
import 'package:readin_flutter/features/profile/data/reading_stats.dart';

import '../helpers/test_rig.dart';

Map<String, dynamic> _ann(String id, {String color = 'green', String note = ''}) => {
      '_id': id,
      'bookId': 'b1',
      'type': note.isEmpty ? 'highlight' : 'note',
      'cfiRange': 'epubcfi(/6/4!/4/2,/1:0,/1:5)',
      'selectedText': 'Hello world',
      'note': note,
      'color': color,
      'chapterTitle': 'Chapter 1',
      'chapterIndex': 2,
      'createdAt': '2026-02-01T10:00:00.000Z',
    };

TestReply _ok(Object? data, {int status = 200}) =>
    (status: status, body: {'success': true, 'message': 'ok', 'data': data});

void main() {
  group('models', () {
    test('Annotation.fromJson (server shape, unknown colour → yellow)', () {
      final a = Annotation.fromJson(_ann('x1', color: 'magenta', note: 'hi'));
      expect(a.id, 'x1');
      expect(a.color, HighlightColor.yellow);
      expect(a.hasNote, isTrue);
      expect(a.chapterIndex, 2);
      expect(a.createdAt.year, 2026);
      expect(Annotation.fromJson({'_id': 'q'}).type, 'highlight');
    });

    test('HighlightColor hex for epub.js', () {
      expect(HighlightColor.yellow.hex, '#FDE68A');
      expect(HighlightColor.purple.hex, '#C4B5FD');
      expect(HighlightColor.parse('pink'), HighlightColor.pink);
    });

    test('NewAnnotation obeys the server schema limits', () {
      final j = NewAnnotation(
        type: 'note',
        cfiRange: 'c',
        selectedText: 'a' * 2500,
        note: 'n' * 6000,
        color: HighlightColor.blue,
        chapterIndex: -4,
      ).toJson('book9');
      expect((j['selectedText'] as String).length, 2000);
      expect((j['note'] as String).length, 5000);
      expect(j['color'], 'blue');
      expect(j['chapterIndex'], 0);
      expect(j['bookId'], 'book9');
    });

    test('NewBookmark clamps', () {
      final j = NewBookmark(
        cfi: 'c', label: 'l' * 300, chapterTitle: '', chapterIndex: -1, percentage: 130,
      ).toJson('b');
      expect((j['label'] as String).length, 200);
      expect(j['percentage'], 100.0);
      expect(j['chapterIndex'], 0);
    });

    test('ReadingStats tolerates old servers', () {
      final s = ReadingStats.fromJson({'totalBooks': 3, 'booksCompleted': 2, 'annotationCount': '7'});
      expect(s.completedBooks, 2);
      expect(s.annotationCount, 7);
      expect(s.totalReadingTimeSeconds, 0);
    });
  });

  group('repositories (real response shapes)', () {
    test('list unwraps {annotations:[…]} (object, not a bare array)', () async {
      final adapter = FakeAdapter((o) {
        expect(o.path, '/annotations/book/b1');
        return _ok({'annotations': [_ann('1'), _ann('2')]});
      });
      final repo = AnnotationsRepository(await makeTestApi(adapter));
      final res = await repo.list('b1');
      expect(res.dataOrNull!.map((a) => a.id), ['1', '2']);
    });

    test('list: missing key → empty list, not a crash', () async {
      final repo = AnnotationsRepository(await makeTestApi(FakeAdapter((_) => _ok({}))));
      expect((await repo.list('b1')).dataOrNull, isEmpty);
    });

    test('create → POST /annotations → {annotation}; 403 keeps the server message', () async {
      var status = 201;
      Object? sent;
      final adapter = FakeAdapter((o) {
        expect(o.method, 'POST');
        expect(o.path, '/annotations');
        sent = o.data;
        return status == 201
            ? _ok({'annotation': _ann('new1')}, status: 201)
            : (status: 403, body: {
                'success': false,
                'message': 'Free plan is limited to 20 annotations. Upgrade to Premium for unlimited annotations.',
              });
      });
      final repo = AnnotationsRepository(await makeTestApi(adapter));
      const n = NewAnnotation(type: 'highlight', cfiRange: 'c', selectedText: 't');

      final ok = await repo.create('b1', n);
      expect(ok.dataOrNull!.id, 'new1');
      expect((sent as Map)['bookId'], 'b1');

      status = 403;
      final limited = await repo.create('b1', n);
      expect(limited.exceptionOrNull!.statusCode, 403);
      expect(limited.exceptionOrNull!.message, contains('limited to 20 annotations'));
    });

    test('update sends only the given fields', () async {
      Object? sent;
      final adapter = FakeAdapter((o) {
        sent = o.data;
        expect(o.method, 'PUT');
        expect(o.path, '/annotations/a9');
        return _ok({'annotation': _ann('a9', note: 'edited')});
      });
      final repo = AnnotationsRepository(await makeTestApi(adapter));
      final res = await repo.update('a9', note: 'edited');
      expect(sent, {'note': 'edited'});
      expect(res.dataOrNull!.note, 'edited');
    });

    test('bookmarks list/create parse their own envelopes', () async {
      final adapter = FakeAdapter((o) {
        if (o.method == 'GET') {
          return _ok({
            'bookmarks': [
              {'_id': 'k1', 'bookId': 'b1', 'cfi': 'c1', 'label': 'L', 'percentage': 12.5}
            ],
          });
        }
        return _ok({
          'bookmark': {'_id': 'k2', 'bookId': 'b1', 'cfi': 'c2', 'percentage': 50},
        }, status: 201);
      });
      final repo = BookmarksRepository(await makeTestApi(adapter));
      expect((await repo.list('b1')).dataOrNull!.single.percentage, 12.5);
      final created = await repo.create(
        'b1',
        const NewBookmark(cfi: 'c2', label: '', chapterTitle: '', chapterIndex: 0, percentage: 50),
      );
      expect(created.dataOrNull!.id, 'k2');
    });
  });

  group('AnnotationsNotifier', () {
    test('loads, creates, and deletes optimistically (restores on failure)', () async {
      var deleteStatus = 500;
      final adapter = FakeAdapter((o) {
        if (o.method == 'GET') return _ok({'annotations': [_ann('1'), _ann('2')]});
        if (o.method == 'POST') return _ok({'annotation': _ann('3')}, status: 201);
        if (o.method == 'DELETE') {
          return deleteStatus == 200
              ? _ok(null)
              : (status: 500, body: {'success': false, 'message': 'boom'});
        }
        return (status: 404, body: {'success': false});
      });
      final n = AnnotationsNotifier(AnnotationsRepository(await makeTestApi(adapter)), 'b1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(n.state.isLoading, isFalse);
      expect(n.state.items.map((a) => a.id), ['1', '2']);

      await n.create(const NewAnnotation(type: 'highlight', cfiRange: 'c', selectedText: 't'));
      expect(n.state.items.map((a) => a.id), ['1', '2', '3']);

      final failed = await n.delete('2'); // server error → row comes back
      expect(failed.isFailure, isTrue);
      expect(n.state.items.map((a) => a.id), ['1', '2', '3']);

      deleteStatus = 200;
      final ok = await n.delete('2');
      expect(ok.isSuccess, isTrue);
      expect(n.state.items.map((a) => a.id), ['1', '3']);
      n.dispose();
    });

    test('local files (empty bookId) never touch the network', () async {
      final adapter = FakeAdapter((_) => _ok({'annotations': []}));
      final n = AnnotationsNotifier(AnnotationsRepository(await makeTestApi(adapter)), '');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(adapter.requests, isEmpty);
      expect(n.state.isLoading, isFalse);
      n.dispose();
    });
  });

  group('BookmarksNotifier', () {
    test('byCfi + idempotent add (no duplicate rows)', () async {
      final adapter = FakeAdapter((o) {
        if (o.method == 'GET') return _ok({'bookmarks': []});
        return _ok({
          'bookmark': {'_id': 'same', 'bookId': 'b1', 'cfi': 'c1', 'percentage': 10},
        }, status: 201);
      });
      final n = BookmarksNotifier(BookmarksRepository(await makeTestApi(adapter)), 'b1');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      const b = NewBookmark(cfi: 'c1', label: '', chapterTitle: '', chapterIndex: 0, percentage: 10);
      await n.add(b);
      await n.add(b); // server returns the same bookmark again
      expect(n.state.items.length, 1);
      expect(n.state.byCfi('c1')!.id, 'same');
      expect(n.state.byCfi('other'), isNull);
      expect(n.state.byCfi(null), isNull);
      n.dispose();
    });
  });
}
