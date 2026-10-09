import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/native_bridge.dart';
import '../../audio/data/tts_engine.dart';
import '../../audio/providers/audio_controller.dart';
import '../widgets/epub_view.dart';

class ReadAloudState {
  const ReadAloudState({
    this.active = false,
    this.playing = false,
    this.index = 0,
    this.total = 0,
    this.speed = 1.0,
  });

  /// The read-aloud bar is shown (even while paused).
  final bool active;
  final bool playing;
  final int index;
  final int total;
  final double speed;

  ReadAloudState copyWith({bool? active, bool? playing, int? index, int? total, double? speed}) =>
      ReadAloudState(
        active: active ?? this.active,
        playing: playing ?? this.playing,
        index: index ?? this.index,
        total: total ?? this.total,
        speed: speed ?? this.speed,
      );
}

/// Reads the open EPUB aloud, sentence by sentence, highlighting the sentence
/// being spoken and turning pages / chapters by itself. Lives only while the
/// reader is open (the foreground notification keeps it alive with the screen off).
class ReadAloudController extends StateNotifier<ReadAloudState> {
  ReadAloudController(this._ref, this._engine) : super(const ReadAloudState());

  final Ref _ref;
  final TtsEngine _engine;

  EpubViewController? _epub;
  String _title = 'ReadIn';
  List<String> _sentences = const [];
  StreamSubscription<String>? _actions;
  int _emptyChapters = 0;
  bool _awaitingChapter = false;

  void attach(EpubViewController epub, String title) {
    _epub = epub;
    _title = title;
  }

  void _show() {
    ReadAloudNotification.show(
      owner: 'book',
      title: _title,
      text: 'Reading aloud',
      playing: state.playing,
    );
  }

  Future<void> start() async {
    if (_epub == null) return;
    // Only one voice at a time.
    _ref.read(audioControllerProvider.notifier).stop();
    _emptyChapters = 0;
    state = state.copyWith(active: true, playing: true, index: 0, total: 0);
    try {
      _actions ??= ReadAloudNotification.actionsFor('book').listen(_onAction);
    } catch (_) {}
    _show();
    _epub!.ttsPrepare();
  }

  void _onAction(String a) {
    switch (a) {
      case 'play':
        resume();
      case 'pause':
        pause();
      case 'next':
        skip(1);
      case 'prev':
        skip(-1);
      case 'stop':
        stop();
    }
  }

  /// Answer of `ttsPrepare()` from the page.
  void onSentences(List<String> items, int start) {
    if (!mounted || !state.active) return;
    _awaitingChapter = false;
    if (items.isEmpty) {
      // Empty chapter (cover, images…): skip ahead, but never loop forever.
      if (++_emptyChapters > 5) {
        stop();
        return;
      }
      _nextChapter();
      return;
    }
    _emptyChapters = 0;
    _sentences = items;
    state = state.copyWith(index: start.clamp(0, items.length - 1).toInt(), total: items.length);
    if (state.playing) _speak();
  }

  void _speak() {
    if (!mounted || !state.active) return;
    final i = state.index;
    if (i >= _sentences.length) {
      _nextChapter();
      return;
    }
    _epub?.ttsHighlight(i);
    _engine.speak(
      _sentences[i],
      rate: engineRateFor(state.speed),
      onDone: () {
        if (!mounted || !state.playing || state.index != i) return;
        state = state.copyWith(index: i + 1);
        _speak();
      },
      onError: (_) {
        if (mounted) pause();
      },
    );
  }

  void _nextChapter() {
    if (_awaitingChapter) return;
    _awaitingChapter = true;
    _epub?.ttsClear();
    _epub?.nextSection();
    // Give the page time to render the next chapter before reading it.
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted && state.active) _epub?.ttsPrepare();
    });
  }

  void pause() {
    _engine.stop();
    if (!mounted) return;
    state = state.copyWith(playing: false);
    _show();
  }

  void resume() {
    if (!state.active) return;
    state = state.copyWith(playing: true);
    _show();
    if (_sentences.isEmpty) {
      _epub?.ttsPrepare();
    } else {
      _speak();
    }
  }

  /// ±1 sentence (the notification and the bar use ±1; the bar can hold to repeat).
  void skip(int delta) {
    if (_sentences.isEmpty) return;
    _engine.stop();
    final i = (state.index + delta).clamp(0, _sentences.length - 1).toInt();
    state = state.copyWith(index: i);
    if (state.playing) {
      _speak();
    } else {
      _epub?.ttsHighlight(i);
    }
  }

  void setSpeed(double v) {
    state = state.copyWith(speed: v);
    if (state.playing) {
      _engine.stop();
      _speak();
    }
  }

  void stop() {
    _engine.stop();
    _epub?.ttsClear();
    _sentences = const [];
    if (mounted) state = state.copyWith(active: false, playing: false, index: 0, total: 0);
    ReadAloudNotification.stop(owner: 'book');
  }

  @override
  void dispose() {
    _actions?.cancel();
    _engine.stop();
    ReadAloudNotification.stop(owner: 'book');
    super.dispose();
  }
}

final readAloudProvider =
    StateNotifierProvider.autoDispose<ReadAloudController, ReadAloudState>(
  (ref) => ReadAloudController(ref, ref.watch(ttsEngineProvider)),
);
