import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/core/formats.dart';
import 'package:readin_flutter/features/annotations/data/annotation_models.dart';
import 'package:readin_flutter/features/library/data/datasources/library_remote_datasource.dart';
import 'package:readin_flutter/features/library/data/local_import_service.dart';
import 'package:readin_flutter/features/library/data/local_library_store.dart';
import 'package:readin_flutter/features/library/data/models/book.dart';
import 'package:readin_flutter/features/library/data/repositories/library_repository.dart';
import 'package:readin_flutter/features/library/data/services/download_service.dart';
import 'package:readin_flutter/features/library/providers/library_providers.dart';
import 'package:readin_flutter/features/notes/notes_export.dart';
import 'package:readin_flutter/features/notes/quote_card.dart';
import 'package:readin_flutter/features/shelves/badges.dart';
import 'package:readin_flutter/features/shelves/shelf_models.dart';

import '../helpers/test_rig.dart';

Book _book(String id, {String format = 'epub', double pct = 0, bool done = false, DateTime? last, String fp = ''}) =>
    Book.fromJson({
      '_id': id,
      'title': 'T$id',
      'author': 'A',
      'originalFormat': format,
      'status': 'ready',
      'source': 'local',
      'fingerprint': fp,
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
      if (pct > 0 || done)
        'progress': {
          'percentage': done ? 100 : pct,
          'isCompleted': done,
          'lastReadAt': (last ?? DateTime(2026, 3, 1)).toIso8601String(),
        },
    });

Annotation _ann(String text, {String note = '', String chapter = 'Chapter 1'}) => Annotation.fromJson({
      '_id': text.hashCode.toString(),
      'bookId': 'b',
      'type': note.isEmpty ? 'highlight' : 'note',
      'cfiRange': 'c',
      'selectedText': text,
      'note': note,
      'color': 'yellow',
      'chapterTitle': chapter,
      'chapterIndex': 0,
      'createdAt': '2026-02-03T10:00:00Z',
    });

void main() {
  group('formats', () {
    test('extensions and kinds', () {
      expect(extensionOfName('My Book.PDF'), 'pdf');
      expect(extensionOfName('/a/b/report.final.docx'), 'docx');
      expect(extensionOfName('noext'), '');
      expect(extensionOfName('trailing.'), '');
      expect(kindOfFormat('epub'), ViewerKind.epub);
      expect(kindOfFormat('pdf'), ViewerKind.pdf);
      for (final f in ['docx', 'xlsx', 'pptx', 'txt', 'md', 'csv', 'html', 'fb2', 'odt']) {
        expect(kindOfFormat(f), ViewerKind.document, reason: f);
      }
      expect(kindOfFormat('cbz'), ViewerKind.comic);
      for (final f in ['mobi', 'doc', 'rtf', 'xls', 'ppt', 'cbr', 'azw3', 'weird']) {
        expect(kindOfFormat(f), ViewerKind.external, reason: f);
      }
    });

    test('normalize / storage extension / support', () {
      expect(normalizeFormat('DOCX'), 'docx');
      expect(normalizeFormat('zzz'), 'other');
      expect(normalizeFormat(null), 'other');
      expect(storageExtension('other'), 'bin');
      expect(storageExtension('xlsx'), 'xlsx');
      expect(isSupportedFileName('a.csv'), isTrue);
      expect(isSupportedFileName('a.exe'), isFalse);
      expect(mimeOfFormat('pdf'), 'application/pdf');
      expect(kZipFormats, containsAll(['epub', 'docx', 'xlsx', 'pptx', 'odt', 'cbz']));
    });

    test('Book.kind follows the format', () {
      expect(_book('1', format: 'docx').kind, ViewerKind.document);
      expect(_book('2', format: 'epub').kind, ViewerKind.epub);
      expect(_book('3', format: 'mobi').kind, ViewerKind.external);
      expect(_book('local_x').isLocalFirst, isTrue);
    });
  });

  group('notes export', () {
    final groups = [
      NoteGroup(bookId: 'b', title: 'Emma', author: 'Jane Austen', items: [
        _ann('It is a truth', note: 'Opening line!'),
        _ann('Second quote', chapter: ''),
      ]),
      const NoteGroup(bookId: 'c', title: 'Empty', author: '', items: []),
    ];

    test('markdown', () {
      final md = exportMarkdown(groups);
      expect(md, contains('# Emma'));
      expect(md, contains('*Jane Austen*'));
      expect(md, contains('> It is a truth'));
      expect(md, contains('**Note:** Opening line!'));
      expect(md, contains('Chapter 1'));
      expect(md, isNot(contains('Empty'))); // books without notes are skipped
    });

    test('plain text', () {
      final t = exportText(groups);
      expect(t, contains('EMMA'));
      expect(t, contains('by Jane Austen'));
      expect(t, contains('1. "It is a truth"'));
      expect(t, contains('Note: Opening line!'));
    });

    test('search quote, note, chapter and book title', () {
      expect(searchNotes(groups, '').length, 2);
      expect(searchNotes(groups, 'truth').single.items.length, 1);
      expect(searchNotes(groups, 'OPENING').single.items.length, 1);
      expect(searchNotes(groups, 'austen').single.items.length, 2); // by author → all
      expect(searchNotes(groups, 'zzz'), isEmpty);
    });
  });

  group('quote card', () {
    test('font size shrinks with length, long text is shortened', () {
      expect(quoteFontSize('short'), greaterThan(quoteFontSize('x' * 200)));
      expect(quoteFontSize('x' * 200), greaterThan(quoteFontSize('x' * 400)));
      final long = shortenQuote('word ' * 200);
      expect(long.length, lessThanOrEqualTo(420));
      expect(long.endsWith('…'), isTrue);
      expect(shortenQuote('  a   b \n c '), 'a b c');
    });
  });

  group('shelves, challenge, badges', () {
    test('effective status: explicit choice wins, otherwise derived from progress', () {
      const d = ShelfData();
      expect(effectiveStatus(_book('1'), d), ReadStatus.none);
      expect(effectiveStatus(_book('2', pct: 30), d), ReadStatus.reading);
      expect(effectiveStatus(_book('3', done: true), d), ReadStatus.finished);
      final d2 = ShelfData(status: {'1': ReadStatus.want, '3': ReadStatus.reading});
      expect(effectiveStatus(_book('1'), d2), ReadStatus.want);
      expect(effectiveStatus(_book('3', done: true), d2), ReadStatus.reading);
    });

    test('finished this year uses the finish date', () {
      final books = [
        _book('1', done: true, last: DateTime(2026, 2, 1)),
        _book('2', done: true, last: DateTime(2025, 12, 31)),
        _book('3', pct: 50),
      ];
      expect(finishedInYear(books, const ShelfData(), 2026), 1);
      expect(finishedInYear(books, const ShelfData(), 2025), 1);
      final d = ShelfData(
        status: {'3': ReadStatus.finished},
        finishedAt: {'3': DateTime(2026, 5, 5)},
      );
      expect(finishedInYear(books, d, 2026), 2);
    });

    test('ShelfData survives encode/decode; garbage decodes to defaults', () {
      final d = ShelfData(
        status: {'a': ReadStatus.want, 'b': ReadStatus.finished},
        finishedAt: {'b': DateTime.utc(2026, 4, 2)},
        shelves: const [Shelf(id: '1', name: 'Sci-fi', bookIds: {'a'})],
        yearlyGoal: 24,
      );
      final back = ShelfData.decode(d.encode());
      expect(back.status['a'], ReadStatus.want);
      expect(back.finishedAt['b']!.year, 2026);
      expect(back.shelves.single.name, 'Sci-fi');
      expect(back.shelves.single.bookIds, {'a'});
      expect(back.yearlyGoal, 24);
      expect(ShelfData.decode('not json').yearlyGoal, 12);
      expect(ShelfData.decode(null).shelves, isEmpty);
    });

    test('challenge pace', () {
      final jul1 = DateTime(2026, 7, 2);
      expect(challengePace(goal: 12, finished: 12, now: jul1), contains('complete'));
      expect(challengePace(goal: 12, finished: 9, now: jul1), contains('ahead'));
      expect(challengePace(goal: 12, finished: 6, now: jul1), 'Right on track');
      expect(challengePace(goal: 12, finished: 2, now: jul1), contains('behind'));
    });

    test('badges unlock at their targets and report progress', () {
      final none = evaluateBadges(const BadgeInput());
      expect(none.where((b) => b.unlocked), isEmpty);
      final some = evaluateBadges(const BadgeInput(
        finishedBooks: 5,
        streak: 7,
        readingSeconds: 3600,
        annotations: 9,
        libraryBooks: 10,
      ));
      bool has(String id) => some.firstWhere((b) => b.def.id == id).unlocked;
      expect(has('first_book'), isTrue);
      expect(has('books_5'), isTrue);
      expect(has('books_10'), isFalse);
      expect(has('streak_7'), isTrue);
      expect(has('streak_30'), isFalse);
      expect(has('hours_1'), isTrue);
      expect(has('notes_10'), isFalse);
      expect(has('collector'), isTrue);
      final notes = some.firstWhere((b) => b.def.id == 'notes_10');
      expect(notes.progress, closeTo(0.9, 1e-9));
    });
  });

  group('offline-first library store', () {
    late Directory tmp;
    late LocalLibraryStore store;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('readin_store_');
      store = LocalLibraryStore(documentsDir: () async => tmp);
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('cache round trip, per user, corrupt file = no cache', () async {
      expect(await store.readCache('u1'), isNull);
      final lib = LibraryResponse(
        books: [_book('1'), _book('2', pct: 40)],
        meta: LibraryMeta.empty,
      );
      await store.writeCache('u1', lib);
      final back = await store.readCache('u1');
      expect(back!.books.map((b) => b.id), ['1', '2']);
      expect(back.books.last.progress!.percentage, 40);
      expect(await store.readCache('u2'), isNull);

      File('${tmp.path}/library_cache_u1.json').writeAsStringSync('{{{ nope');
      expect(await store.readCache('u1'), isNull);
    });

    test('pending books: add (newest first), replace, remove', () async {
      await store.addPending('u1', _book('local_a', format: 'docx'));
      await store.addPending('u1', _book('local_b'));
      await store.addPending('u1', _book('local_a', format: 'pdf')); // same id → replaced
      var list = await store.readPending('u1');
      expect(list.map((b) => b.id), ['local_a', 'local_b']);
      expect(list.first.format, 'pdf');
      expect(list.every((b) => b.pendingSync), isTrue);
      await store.removePending('u1', 'local_a');
      list = await store.readPending('u1');
      expect(list.map((b) => b.id), ['local_b']);
    });

    test('mergeLibrary puts pending first and never duplicates', () {
      final server = LibraryResponse(
        books: [_book('s1', fp: 'F1'), _book('s2')],
        meta: LibraryMeta.empty,
      );
      final pending = [
        _book('local_x', fp: 'F9'),
        _book('local_y', fp: 'F1'), // already registered under another id
      ];
      final merged = mergeLibrary(server, pending);
      expect(merged.books.map((b) => b.id), ['local_x', 's1', 's2']);
      expect(merged.meta.total, 3);
    });
  });

  group('local-first import', () {
    late Directory tmp;
    late LocalLibraryStore store;
    late DownloadService downloads;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('readin_imp_');
      store = LocalLibraryStore(documentsDir: () async => Directory('${tmp.path}/meta')..createSync());
      downloads = DownloadService(
        dio: Dio(),
        documentsDir: () async => Directory('${tmp.path}/docs')..createSync(),
      );
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    File write(String name, List<int> bytes) => File('${tmp.path}/$name')..writeAsBytesSync(bytes);

    Future<LocalImportService> service(TestReply Function(RequestOptions) handler) async {
      final api = await makeTestApi(FakeAdapter(handler));
      return LocalImportService(
        downloads: downloads,
        store: store,
        repo: LibraryRepository(LibraryRemoteDataSource(api)),
        userId: () => 'u1',
      );
    }

    TestReply registered(RequestOptions o) => (
          status: 201,
          body: {
            'success': true,
            'data': {
              'book': {
                '_id': 'srv1',
                'title': 'Notes',
                'originalFormat': 'txt',
                'status': 'ready',
                'source': 'local',
                'createdAt': '2026-01-01T00:00:00Z',
                'updatedAt': '2026-01-01T00:00:00Z',
              },
            },
          },
        );

    test('a text file is registered, stored on the phone under the server id', () async {
      final s = await service(registered);
      final f = write('My_Notes.txt', utf8.encode('hello world, this is a note'));
      final o = await s.importOne(f.path);
      expect(o.status, ImportStatus.imported);
      expect(o.book!.id, 'srv1');
      final stored = await downloads.findLocal('srv1');
      expect(stored, isNotNull);
      expect(stored!.path.endsWith('srv1.txt'), isTrue);
      expect(stored.readAsStringSync(), 'hello world, this is a note');
      expect(await store.readPending('u1'), isEmpty);
    });

    test('server unreachable → kept on the phone as pending, then synced later', () async {
      var online = false;
      final s = await service((o) => online
          ? registered(o)
          : (status: 503, body: {'success': false, 'message': 'asleep'}));
      final f = write('plan.csv', utf8.encode('a,b\n1,2'));
      final o = await s.importOne(f.path);
      expect(o.status, ImportStatus.pending);
      expect(o.book!.id, startsWith('local_'));
      expect(await downloads.findLocal(o.book!.id), isNotNull);
      expect((await store.readPending('u1')).length, 1);

      online = true;
      final synced = await s.syncPending();
      expect(synced, 1);
      expect(await store.readPending('u1'), isEmpty);
      expect(await downloads.findLocal('srv1'), isNotNull); // file moved to the server id
      expect(await downloads.findLocal(o.book!.id), isNull);
    });

    test('free-plan limit, unsupported types, corrupt PDF and duplicates', () async {
      final limit = await service((o) => (
            status: 403,
            body: {'success': false, 'message': 'Free plan is limited to 10 books.'},
          ));
      final f = write('a.txt', utf8.encode('some text here'));
      final o = await limit.importOne(f.path);
      expect(o.status, ImportStatus.limit);
      expect(o.message, contains('limited'));
      expect(await store.readPending('u1'), isEmpty);

      final s = await service(registered);
      expect((await s.importOne(write('tool.exe', [1, 2, 3]).path)).status, ImportStatus.unsupported);
      expect((await s.importOne(write('empty.txt', []).path)).status, ImportStatus.failed);
      final fake = await s.importOne(write('fake.pdf', utf8.encode('not a pdf at all')).path);
      expect(fake.status, ImportStatus.failed);
      expect(fake.message, contains('valid PDF'));

      final f2 = write('same.txt', utf8.encode('identical content'));
      final first = await s.importOne(f2.path);
      final dup = await s.importOne(f2.path, knownFingerprints: {first.book!.fingerprint});
      expect(first.book!.fingerprint, isNotEmpty);
      expect(dup.status, ImportStatus.duplicate);
    });

    test('fingerprint: identical files match, different files differ', () async {
      final a = write('a.bin', List.filled(1000, 7));
      final b = write('b.bin', List.filled(1000, 7));
      final c = write('c.bin', List.filled(1001, 7));
      expect(await fingerprintOf(a), await fingerprintOf(b));
      expect(await fingerprintOf(a), isNot(await fingerprintOf(c)));
    });
  });
}
