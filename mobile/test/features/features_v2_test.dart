import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readin_flutter/core/errors/app_exception.dart';
import 'package:readin_flutter/core/api/api_result.dart';
import 'package:readin_flutter/features/audio/data/tts_engine.dart';
import 'package:readin_flutter/features/audio/providers/audio_controller.dart';
import 'package:readin_flutter/features/goals/reading_goal.dart';
import 'package:readin_flutter/features/import/data/import_models.dart';
import 'package:readin_flutter/features/library/data/services/download_service.dart';
import 'package:readin_flutter/features/reader/data/dictionary_service.dart';
import 'package:readin_flutter/features/reader/data/progress_sync.dart';
import 'package:readin_flutter/features/reader/data/reader_models.dart';

import '../helpers/test_rig.dart';

class _Tts implements TtsEngine {
  @override
  Future<void> speak(String text,
      {required double rate,
      required void Function() onDone,
      required void Function(String message) onError}) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  group('time left formatting', () {
    test('formatMinutes', () {
      expect(formatMinutes(0), '<1 min');
      expect(formatMinutes(45), '45 min');
      expect(formatMinutes(60), '1h');
      expect(formatMinutes(130), '2h 10m');
    });
  });

  group('ReaderPrefs', () {
    const base = ReaderPrefs(fontSize: 17, fontFamily: 'serif', theme: 'night');

    test('defaults + page json (no brightness / volume / flow)', () {
      expect(base.lineHeight, 1.6);
      expect(base.margin, 16);
      expect(base.flow, 'paged');
      expect(base.isScroll, isFalse);
      expect(base.toPageJson(), {
        'fontSize': 17,
        'fontFamily': 'serif',
        'theme': 'night',
        'lineHeight': 1.6,
        'margin': 16,
        'align': 'left',
      });
    });

    test('every field takes part in equality (so the page is told about changes)', () {
      expect(base == base.copyWith(), isTrue);
      for (final other in [
        base.copyWith(fontSize: 18),
        base.copyWith(fontFamily: 'sans-serif'),
        base.copyWith(theme: 'light'),
        base.copyWith(lineHeight: 1.8),
        base.copyWith(margin: 32),
        base.copyWith(align: 'justify'),
        base.copyWith(flow: 'scroll'),
        base.copyWith(brightness: 0.5),
        base.copyWith(volumeKeys: false),
      ]) {
        expect(base == other, isFalse);
      }
    });

    test('SearchHit collapses whitespace', () {
      final h = SearchHit.fromJson({'cfi': 'c', 'excerpt': 'a\n  b\t c '});
      expect(h.excerpt, 'a b c');
    });
  });

  group('dictionary', () {
    test('cleanWord accepts one word only', () {
      expect(cleanWord('  Serendipity. '), 'serendipity');
      expect(cleanWord('“Hello,”'), 'hello');
      expect(cleanWord("don't"), "don't");
      expect(cleanWord('well-known'), 'well-known');
      expect(cleanWord('two words'), isNull);
      expect(cleanWord('a'), isNull);
      expect(cleanWord('1984'), isNull);
      expect(cleanWord(''), isNull);
    });

    test('parseDictionaryResponse', () {
      final e = parseDictionaryResponse([
        {
          'word': 'hello',
          'phonetic': '/həˈləʊ/',
          'meanings': [
            {
              'partOfSpeech': 'noun',
              'definitions': [
                {'definition': 'A greeting.', 'example': 'She said hello.'},
                {'definition': ''},
              ],
              'synonyms': ['hi', 'greeting'],
            },
            {'partOfSpeech': 'verb', 'definitions': []},
          ],
        },
      ])!;
      expect(e.word, 'hello');
      expect(e.phonetic, '/həˈləʊ/');
      expect(e.meanings.length, 1); // the empty verb entry is dropped
      expect(e.meanings.single.definitions.single.example, 'She said hello.');
      expect(e.meanings.single.synonyms, ['hi', 'greeting']);
      expect(parseDictionaryResponse({'title': 'No Definitions Found'}), isNull);
      expect(parseDictionaryResponse([]), isNull);
    });
  });

  group('daily goal', () {
    test('computeStreak counts back from today (or yesterday)', () {
      final today = DateTime(2026, 10, 8);
      final secs = <String, int>{
        '2026-10-08': 0, // nothing yet today
        '2026-10-07': 120,
        '2026-10-06': 61,
        '2026-10-05': 30, // too short -> streak stops
        '2026-10-04': 500,
      };
      int on(DateTime d) => secs[dayKey(d)] ?? 0;
      expect(computeStreak(on, today), 2);
      secs['2026-10-08'] = 90;
      expect(computeStreak(on, today), 3);
      secs.clear();
      expect(computeStreak(on, today), 0);
    });

    test('notifier adds time, tracks the goal and the week', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = MemoryStorage(await SharedPreferences.getInstance());
      var now = DateTime(2026, 10, 8, 9);
      final n = ReadingGoalNotifier(storage, now: () => now);

      expect(n.state.goalMinutes, 20);
      expect(n.state.todaySeconds, 0);
      expect(n.state.progress, 0);
      expect(n.state.last7.length, 7);
      expect(n.state.weekdays.length, 7);

      n.add(600);
      expect(n.state.todayMinutes, 10);
      expect(n.state.progress, closeTo(0.5, 1e-9));
      expect(n.state.goalReached, isFalse);
      expect(n.state.streak, 1);

      n.add(600);
      expect(n.state.goalReached, isTrue);
      n.add(-5); // ignored
      n.add(0); // ignored
      expect(n.state.todaySeconds, 1200);

      n.setGoal(1); // clamped to the minimum
      expect(n.state.goalMinutes, 5);

      now = DateTime(2026, 10, 9, 8); // next morning
      n.refresh();
      expect(n.state.todaySeconds, 0);
      expect(n.state.streak, 1); // yesterday still counts
      expect(n.state.last7.last, 0);
      expect(n.state.last7[5], 1200);
    });
  });

  group('downloads', () {
    test('Gutenberg on-demand links get fast static mirrors first', () {
      expect(
        DownloadService.candidateUrls('https://www.gutenberg.org/ebooks/1342.epub3.images'),
        [
          'https://www.gutenberg.org/cache/epub/1342/pg1342-images.epub',
          'https://www.gutenberg.org/cache/epub/1342/pg1342-images-3.epub',
          'https://www.gutenberg.org/ebooks/1342.epub3.images',
        ],
      );
      expect(DownloadService.candidateUrls('https://gutenberg.org/ebooks/11.epub.images').length, 3);
    });

    test('other hosts are untouched', () {
      expect(
        DownloadService.candidateUrls('https://res.cloudinary.com/x/raw/upload/b.epub'),
        ['https://res.cloudinary.com/x/raw/upload/b.epub'],
      );
    });
  });

  group('import against an un-updated server', () {
    test('"Could not read this PDF" offers to read the file locally', () {
      final f = mapUploadError(const ServerException(
        message:
            'Could not read this PDF. The file may be password-protected or corrupted. Please try a different PDF.',
        statusCode: 400,
      ));
      expect(f.kind, ImportFailureKind.offline);
      expect(f.message, contains('SERVER_UPDATE.md'));
    });
  });

  group('ProgressSync throttle', () {
    test('lifecycle bursts send once; force / dispose always send', () async {
      var t = DateTime(2026, 1, 1, 12);
      var sent = 0;
      final s = ProgressSync(
        now: () => t,
        send: (p, d) async {
          sent++;
          return const Success<void>(null);
        },
      );
      s.update(const ProgressPayload(
        currentCfi: 'c',
        percentage: 1,
        currentChapter: 0,
        currentChapterTitle: '',
        totalChapters: 1,
      ));
      await s.flush();
      expect(sent, 1);
      t = t.add(const Duration(seconds: 3));
      await s.flush(); // too soon
      await s.flush();
      expect(sent, 1);
      await s.pause(); // pause always sends
      expect(sent, 2);
      t = t.add(const Duration(seconds: 11));
      await s.flush();
      expect(sent, 3);
      await s.dispose();
      expect(sent, 4);
    });
  });

  test('audio sleep timer state', () {
    final c = AudioController(_Tts());
    expect(c.state.sleepMinutes, isNull);
    c.setSleepTimer(15);
    expect(c.state.sleepMinutes, 15);
    c.setSleepTimer(30);
    expect(c.state.sleepMinutes, 30);
    c.setSleepTimer(null);
    expect(c.state.sleepMinutes, isNull);
    c.dispose(); // cancels any timer
  });
}
