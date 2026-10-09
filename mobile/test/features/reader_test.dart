import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/core/api/api_result.dart';
import 'package:readin_flutter/core/errors/app_exception.dart';
import 'package:readin_flutter/features/reader/data/progress_sync.dart';
import 'package:readin_flutter/features/reader/data/reader_models.dart';

ProgressPayload _p(int pct, {String cfi = 'epubcfi(/6/4)'}) => ProgressPayload(
      currentCfi: cfi,
      percentage: pct.toDouble(),
      currentChapter: 1,
      currentChapterTitle: 'Chapter 1',
      totalChapters: 10,
    );

void main() {
  group('TOC helpers', () {
    final toc = parseToc([
      {
        'id': 'a',
        'href': 'ch1.xhtml',
        'label': '  One ',
        'subitems': [
          {'id': 'a1', 'href': 'ch1.xhtml#s1', 'label': 'One-A'},
          {'id': 'a2', 'href': 'text/ch1b.xhtml', 'label': 'One-B'},
        ],
      },
      {'id': 'b', 'href': 'OEBPS/ch2.xhtml#top', 'label': 'Two'},
      {'id': 'c', 'href': 'ch3.xhtml', 'label': 'Three'},
    ]);

    test('parseToc trims labels and nests', () {
      expect(toc.length, 3);
      expect(toc.first.label, 'One');
      expect(toc.first.subitems.length, 2);
      expect(toc[1].baseHref, 'OEBPS/ch2.xhtml');
      expect(parseToc(null), isEmpty);
      expect(parseToc('x'), isEmpty);
    });

    test('tocIndexFor returns the TOP-LEVEL index containing the href', () {
      expect(tocIndexFor(toc, 'ch1.xhtml'), 0);
      expect(tocIndexFor(toc, 'text/ch1b.xhtml'), 0); // a sub-item of chapter 1
      expect(tocIndexFor(toc, 'ch2.xhtml'), 1); // epub.js reports without OEBPS/
      expect(tocIndexFor(toc, 'ch3.xhtml'), 2);
      expect(tocIndexFor(toc, 'nope.xhtml'), -1);
      expect(tocIndexFor(toc, ''), -1);
    });
  });

  group('SavedProgress / payload', () {
    test('pdf page parsing', () {
      expect(SavedProgress.fromJson({'currentCfi': 'page:12'}).pdfPage, 12);
      expect(SavedProgress.fromJson({'currentCfi': 'page:0'}).pdfPage, isNull);
      expect(SavedProgress.fromJson({'currentCfi': 'page:x'}).pdfPage, isNull);
      expect(SavedProgress.fromJson({'currentCfi': 'epubcfi(/6/2)'}).pdfPage, isNull);
    });

    test('payload is clamped to what the server accepts', () {
      final j = const ProgressPayload(
        currentCfi: 'epubcfi(/6/2)',
        percentage: 140.5,
        currentChapter: -3,
        currentChapterTitle: 'T',
        totalChapters: -1,
      ).toJson(-9);
      expect(j['percentage'], 100.0);
      expect(j['currentChapter'], 0);
      expect(j['totalChapters'], 0);
      expect(j['readingTimeDeltaSeconds'], 0);
      expect(
        j.keys.toSet(),
        {
          'currentCfi', 'percentage', 'currentChapter', 'currentChapterTitle',
          'totalChapters', 'readingTimeDeltaSeconds',
        },
      );
    });

    test('ReaderPrefs value equality', () {
      const a = ReaderPrefs(fontSize: 17, fontFamily: 'serif', theme: 'dark');
      expect(a, const ReaderPrefs(fontSize: 17, fontFamily: 'serif', theme: 'dark'));
      expect(a == a.copyWith(fontSize: 18), isFalse);
    });
  });

  group('ProgressSync', () {
    late DateTime t;
    late List<(ProgressPayload, int)> sent;
    var fail = false;

    ProgressSync make() => ProgressSync(
          now: () => t,
          send: (p, d) async {
            sent.add((p, d));
            return fail
                ? const Failure<void>(NetworkException())
                : const Success<void>(null);
          },
        );

    setUp(() {
      t = DateTime(2026, 1, 1, 12);
      sent = [];
      fail = false;
    });

    test('nothing to send before the first update', () async {
      final s = make();
      await s.flush();
      expect(sent, isEmpty);
    });

    test('sends the LATEST position with elapsed seconds', () async {
      final s = make();
      s.update(_p(10));
      s.update(_p(20, cfi: 'epubcfi(/6/8)'));
      t = t.add(const Duration(seconds: 40));
      await s.flush();
      expect(sent.length, 1);
      expect(sent.single.$1.percentage, 20);
      expect(sent.single.$1.currentCfi, 'epubcfi(/6/8)');
      expect(sent.single.$2, 40);

      t = t.add(const Duration(seconds: 25));
      await s.flush();
      expect(sent.last.$2, 25); // only the time since the previous send
    });

    test('a failed send keeps the time and retries with the total', () async {
      final s = make();
      s.update(_p(5));
      t = t.add(const Duration(seconds: 30));
      fail = true;
      await s.flush();
      expect(sent.last.$2, 30);

      t = t.add(const Duration(seconds: 30));
      fail = false;
      await s.flush();
      expect(sent.last.$2, 60); // 30 carried + 30 new

      t = t.add(const Duration(seconds: 10));
      await s.flush();
      expect(sent.last.$2, 10); // carry cleared after success
    });

    test('background time is not counted', () async {
      final s = make();
      s.update(_p(5));
      t = t.add(const Duration(seconds: 20));
      await s.pause(); // flushes 20 s
      expect(sent.last.$2, 20);

      t = t.add(const Duration(minutes: 30)); // phone in the pocket
      s.resume();
      t = t.add(const Duration(seconds: 15));
      await s.flush();
      expect(sent.last.$2, 15);
    });

    test('one flush never credits more than the cap (phone left open)', () async {
      final s = make();
      s.update(_p(5));
      t = t.add(const Duration(hours: 5));
      await s.flush();
      expect(sent.last.$2, 600);
    });

    test('concurrent flushes send once', () async {
      final s = make();
      s.update(_p(5));
      t = t.add(const Duration(seconds: 5));
      await Future.wait([s.flush(), s.flush(), s.flush()]);
      expect(sent.length, 1);
    });

    test('dispose flushes a final time and ignores later updates', () async {
      final s = make();
      s.update(_p(30));
      t = t.add(const Duration(seconds: 12));
      await s.dispose();
      expect(sent.length, 1);
      expect(sent.single.$2, 12);
      s.update(_p(99));
      await s.flush();
      expect(sent.length, 1);
    });
  });
}
