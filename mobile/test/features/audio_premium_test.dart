import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/features/audio/data/tts_engine.dart';
import 'package:readin_flutter/features/audio/providers/audio_controller.dart';
import 'package:readin_flutter/features/discover/data/gutenberg_models.dart';
import 'package:readin_flutter/features/premium/data/premium_service.dart';

class FakeTts implements TtsEngine {
  final List<(String, double)> spoken = [];
  int stops = 0;
  void Function()? finish;
  void Function(String)? fail;

  @override
  Future<void> speak(
    String text, {
    required double rate,
    required void Function() onDone,
    required void Function(String message) onError,
  }) async {
    spoken.add((text, rate));
    finish = onDone;
    fail = onError;
  }

  @override
  Future<void> stop() async => stops++;
}

const _text =
    'First sentence is here. Second sentence follows it. Third one arrives now. '
    'Fourth is quite long indeed. Fifth closes the passage.';

void main() {
  group('splitIntoChunks (RN splitIntoChunks)', () {
    test('drops tiny fragments, packs up to maxChars', () {
      final chunks = splitIntoChunks('Hi. Ok. This is a proper sentence. Another proper one!', maxChars: 40);
      // "Hi." and "Ok." are <= 5 chars and are dropped.
      expect(chunks, ['This is a proper sentence.', 'Another proper one!']);
    });

    test('never exceeds maxChars unless one sentence is longer', () {
      final long = List.filled(40, 'This is sentence number one.').join(' ');
      final chunks = splitIntoChunks(long, maxChars: 300);
      expect(chunks.length, greaterThan(1));
      expect(chunks.every((c) => c.length <= 300), isTrue);
    });

    test('empty / whitespace', () {
      expect(splitIntoChunks(''), isEmpty);
      expect(splitIntoChunks('   '), isEmpty);
    });
  });

  test('speed helpers', () {
    expect(engineRateFor(1.0), 0.5);
    expect(engineRateFor(2.0), 1.0);
    expect(engineRateFor(0.75), closeTo(0.375, 1e-9));
    expect(speedLabel(1.0), '1×');
    expect(speedLabel(1.25), '1.25×');
    expect(speedLabel(2.0), '2×');
  });

  group('AudioController', () {
    late FakeTts tts;
    late AudioController c;

    setUp(() {
      tts = FakeTts();
      c = AudioController(tts)
        ..load(bookId: '1', title: 'T', coverUrl: '', text: _text);
    });
    tearDown(() => c.dispose());

    // Force one chunk per sentence for deterministic tests.
    AudioController five() {
      final x = AudioController(tts);
      x.load(bookId: '1', title: 'T', coverUrl: '', text: _text);
      return x;
    }

    test('load shows the mini player but does not start', () {
      expect(c.state.miniVisible, isTrue);
      expect(c.state.isPlaying, isFalse);
      expect(c.state.total, greaterThan(0));
      expect(tts.spoken, isEmpty);
    });

    test('play speaks the current chunk at the speed-based rate', () {
      c.play();
      expect(c.state.isPlaying, isTrue);
      expect(tts.spoken.single.$2, 0.5);
    });

    test('auto-advances when an utterance completes; finishing rewinds + closes', () {
      c.play();
      final total = c.state.total;
      for (var i = 0; i < total; i++) {
        expect(c.state.index, i);
        tts.finish!();
      }
      expect(c.state.isPlaying, isFalse);
      expect(c.state.miniVisible, isFalse);
      expect(c.state.index, 0);
    });

    test('pause stops speech; play resumes the SAME chunk', () {
      c.play();
      tts.finish!(); // now at index 1 (if there is more than one chunk)
      final idx = c.state.index;
      c.pause();
      expect(c.state.isPlaying, isFalse);
      expect(tts.stops, greaterThan(0));
      final spokenBefore = tts.spoken.length;
      c.play();
      expect(c.state.index, idx);
      expect(tts.spoken.length, spokenBefore + 1);
    });

    test('a stale completion after pause is ignored', () {
      c.play();
      final stale = tts.finish!;
      c.pause();
      stale();
      expect(c.state.index, 0);
    });

    test('seek / skip clamp and re-speak only while playing', () {
      final x = five();
      x.skip(100);
      expect(x.state.index, x.state.total - 1);
      x.skip(-100);
      expect(x.state.index, 0);
      expect(tts.spoken, isEmpty); // not playing → silent
      x.play();
      final n = tts.spoken.length;
      x.seek(0);
      expect(tts.spoken.length, n + 1);
      x.dispose();
    });

    test('changing speed while playing restarts the chunk at the new rate', () {
      c.play();
      c.setSpeed(2.0);
      expect(c.state.speed, 2.0);
      expect(tts.spoken.last.$2, 1.0);
      expect(c.state.isPlaying, isTrue);
    });

    test('speed survives loading another text', () {
      c.setSpeed(1.5);
      c.load(bookId: '2', title: 'B', coverUrl: '', text: _text);
      expect(c.state.speed, 1.5);
      expect(c.state.bookId, '2');
      expect(c.state.index, 0);
    });

    test('engine error pauses', () {
      c.play();
      tts.fail!('boom');
      expect(c.state.isPlaying, isFalse);
    });

    test('stop hides the mini player', () {
      c.play();
      c.stop();
      expect(c.state.miniVisible, isFalse);
      expect(c.state.isPlaying, isFalse);
    });

    test('progress is chunk based and consistent', () {
      expect(c.state.progress, 0);
      c.skip(1);
      expect(c.state.progress, closeTo(c.state.index / c.state.total, 1e-9));
    });
  });

  group('Listen preview text (RN handleListen)', () {
    GutenbergBook b(Map<String, dynamic> extra) => GutenbergBook.fromJson({
          'id': 1,
          'title': 'Emma',
          ...extra,
        });

    test('with subjects', () {
      final text = listenPreviewText(b({
        'authors': [
          {'name': 'Austen, Jane'}
        ],
        'subjects': ['Love stories', 'England'],
      }));
      expect(text, 'Emma by Jane Austen. Love stories. England.');
    });

    test('without subjects / authors', () {
      expect(listenPreviewText(b({})), 'Emma. By Unknown. Published by Project Gutenberg.');
    });
  });

  group('Premium', () {
    test('fake service reports "unavailable" like RN dev builds', () async {
      const s = FakePremiumService();
      expect(await s.purchase('premium_annual'), PremiumResult.unavailable);
      expect(await s.restore(), PremiumResult.unavailable);
    });

    test('catalogue matches the spec', () {
      expect(kPremiumPackages.map((p) => p.id), ['premium_monthly', 'premium_annual']);
      expect(kPremiumPackages.last.savings, 'Save 33%');
      expect(kPremiumFeatures.length, 6);
      expect(kPremiumFeatures.first.free, '10 books');
    });
  });
}
