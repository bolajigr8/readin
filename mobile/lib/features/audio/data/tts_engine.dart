import 'package:flutter_tts/flutter_tts.dart';

/// Minimal text-to-speech surface (replaceable in tests).
abstract class TtsEngine {
  /// Speaks [text] at [rate] (0.1–1.0, platform scale where ~0.5 is normal).
  /// [onDone] fires when the utterance finishes **naturally** — never after
  /// [stop] — and [onError] on engine failures.
  Future<void> speak(
    String text, {
    required double rate,
    required void Function() onDone,
    required void Function(String message) onError,
  });

  Future<void> stop();
}

/// `flutter_tts` implementation. Each utterance gets a token; callbacks of a
/// superseded / stopped utterance are ignored (some platforms report
/// "completion" after `stop`). Pause is implemented by the controller as
/// stop + replay of the current sentence, because Android has no real pause.
class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine() : _tts = FlutterTts();

  final FlutterTts _tts;
  int _token = 0;
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    try {
      await _tts.setLanguage('en-US');
      await _tts.awaitSpeakCompletion(false);
    } catch (_) {
      // Best effort: the engine falls back to the system default voice.
    }
  }

  @override
  Future<void> speak(
    String text, {
    required double rate,
    required void Function() onDone,
    required void Function(String message) onError,
  }) async {
    await _configure();
    final id = ++_token;
    _tts.setCompletionHandler(() {
      if (id == _token) onDone();
    });
    _tts.setErrorHandler((dynamic message) {
      if (id == _token) onError('$message');
    });
    _tts.setCancelHandler(() {});
    try {
      await _tts.setSpeechRate(rate);
      await _tts.speak(text);
    } catch (e) {
      if (id == _token) onError('$e');
    }
  }

  @override
  Future<void> stop() async {
    _token++;
    try {
      await _tts.stop();
    } catch (_) {
      // already stopped
    }
  }
}
