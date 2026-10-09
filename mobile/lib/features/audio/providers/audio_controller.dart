import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/native_bridge.dart';
import '../data/tts_engine.dart';

/// RN `splitIntoChunks`: sentences (`(?<=[.!?])\s+`, longer than 5 chars)
/// packed into chunks of at most [maxChars] characters.
List<String> splitIntoChunks(String text, {int maxChars = 300}) {
  final sentences = text
      .split(RegExp(r'(?<=[.!?])\s+'))
      .where((s) => s.trim().length > 5)
      .toList();

  final chunks = <String>[];
  var current = '';
  for (final sentence in sentences) {
    if ((current + sentence).length > maxChars) {
      if (current.isNotEmpty) chunks.add(current.trim());
      current = sentence;
    } else {
      current = current.isNotEmpty ? '$current $sentence' : sentence;
    }
  }
  if (current.isNotEmpty) chunks.add(current.trim());
  return chunks;
}

/// Speed multiplier → engine rate (Android/iOS: 0.5 ≈ normal speed).
double engineRateFor(double speed) => (0.5 * speed).clamp(0.1, 1.0).toDouble();

/// "1×", "1.25×", "2×" (RN prints the JS number).
String speedLabel(double s) =>
    '${s == s.roundToDouble() ? s.toInt().toString() : s.toString()}×';

const List<double> kSpeedOptions = [0.75, 1.0, 1.25, 1.5, 2.0];

class AudioState {
  const AudioState({
    this.isPlaying = false,
    this.bookId,
    this.title,
    this.coverUrl = '',
    this.chunks = const [],
    this.index = 0,
    this.speed = 1.0,
    this.miniVisible = false,
    this.sleepMinutes,
  });

  final bool isPlaying;
  final String? bookId;
  final String? title;
  final String coverUrl;
  final List<String> chunks;

  /// Index of the chunk being (or about to be) spoken.
  final int index;
  final double speed;
  final bool miniVisible;

  /// Sleep timer length in minutes (null = off).
  final int? sleepMinutes;

  int get total => chunks.length;
  double get progress => total == 0 ? 0 : (index / total).clamp(0.0, 1.0);

  AudioState copyWith({
    bool? isPlaying,
    String? bookId,
    String? title,
    String? coverUrl,
    List<String>? chunks,
    int? index,
    double? speed,
    bool? miniVisible,
    int? sleepMinutes,
    bool clearSleep = false,
  }) =>
      AudioState(
        isPlaying: isPlaying ?? this.isPlaying,
        bookId: bookId ?? this.bookId,
        title: title ?? this.title,
        coverUrl: coverUrl ?? this.coverUrl,
        chunks: chunks ?? this.chunks,
        index: index ?? this.index,
        speed: speed ?? this.speed,
        miniVisible: miniVisible ?? this.miniVisible,
        sleepMinutes: clearSleep ? null : (sleepMinutes ?? this.sleepMinutes),
      );
}

/// RN `audioStore` + `useAudio` in one place: load / play / pause / stop /
/// seek / speed, auto-advance, stop on dispose.
///
/// RN showed `totalSentences` (sentence count) next to a **chunk** index; here
/// both are chunk based so the progress bar is consistent.
class AudioController extends StateNotifier<AudioState> {
  AudioController(this._engine) : super(const AudioState());

  final TtsEngine _engine;
  Timer? _sleepTimer;
  StreamSubscription<String>? _actionsSub;

  void _notify() {
    // Foreground notification: keeps the voice alive with the screen off and
    // puts Previous / Play-Pause / Next / Stop on the lock screen.
    try {
      _actionsSub ??= ReadAloudNotification.actionsFor('audio').listen((a) {
        if (!mounted) return;
        switch (a) {
          case 'play':
            play();
          case 'pause':
            pause();
          case 'next':
            skip(5);
          case 'prev':
            skip(-5);
          case 'stop':
            stop();
        }
      });
    } catch (_) {}
    final t = state.title;
    if (t == null) return;
    ReadAloudNotification.show(
      owner: 'audio',
      title: t,
      text: 'Listen preview',
      playing: state.isPlaying,
    );
  }

  /// Pauses the audio after [minutes] (null cancels the timer).
  void setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (minutes == null) {
      state = state.copyWith(clearSleep: true);
      return;
    }
    state = state.copyWith(sleepMinutes: minutes);
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      if (!mounted) return;
      pause();
      state = state.copyWith(clearSleep: true);
    });
  }

  /// Loads a text (replaces any current one). Does not start playing.
  void load({
    required String bookId,
    required String title,
    required String coverUrl,
    required String text,
  }) {
    _engine.stop();
    final chunks = splitIntoChunks(text);
    state = AudioState(
      bookId: bookId,
      title: title,
      coverUrl: coverUrl,
      chunks: chunks,
      speed: state.speed,
      miniVisible: true,
    );
  }

  void play() {
    if (state.chunks.isEmpty) return;
    state = state.copyWith(isPlaying: true);
    _notify();
    _speak();
  }

  /// No real pause on Android: stop and remember the sentence; [play] replays it.
  void pause() {
    _engine.stop();
    state = state.copyWith(isPlaying: false);
    if (state.miniVisible) _notify();
  }

  /// Stops and hides the mini player (book data stays for the full player).
  void stop() {
    _engine.stop();
    state = state.copyWith(isPlaying: false, miniVisible: false);
    ReadAloudNotification.stop(owner: 'audio');
  }

  void seek(int index) {
    if (state.chunks.isEmpty) return;
    final i = index.clamp(0, state.chunks.length - 1);
    _engine.stop();
    state = state.copyWith(index: i);
    if (state.isPlaying) _speak();
  }

  /// ±[delta] sentences (RN skip buttons use 5).
  void skip(int delta) => seek(state.index + delta);

  void setSpeed(double speed) {
    state = state.copyWith(speed: speed);
    if (state.isPlaying) {
      _engine.stop();
      _speak();
    }
  }

  void _speak() {
    final i = state.index;
    if (i >= state.chunks.length) {
      // Finished the whole text: rewind and close like RN.
      _sleepTimer?.cancel();
      _engine.stop();
      state = state.copyWith(isPlaying: false, miniVisible: false, index: 0);
      ReadAloudNotification.stop(owner: 'audio');
      return;
    }
    _engine.speak(
      state.chunks[i],
      rate: engineRateFor(state.speed),
      onDone: () {
        if (!mounted || !state.isPlaying || state.index != i) return;
        state = state.copyWith(index: i + 1);
        _speak();
      },
      onError: (_) {
        if (mounted) pause();
      },
    );
  }

  @override
  void dispose() {
    _actionsSub?.cancel();
    _sleepTimer?.cancel();
    _engine.stop();
    super.dispose();
  }
}

final ttsEngineProvider = Provider<TtsEngine>((ref) => FlutterTtsEngine());

/// App-lifetime player state (the mini player outlives screens).
final audioControllerProvider =
    StateNotifierProvider<AudioController, AudioState>(
  (ref) => AudioController(ref.watch(ttsEngineProvider)),
);
