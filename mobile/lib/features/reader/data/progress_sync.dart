import 'dart:async';

import '../../../core/api/api_result.dart';
import 'reader_models.dart';

typedef ProgressSender = Future<ApiResult<void>> Function(
  ProgressPayload payload,
  int readingTimeDeltaSeconds,
);

/// Debounced / periodic progress upload (UI_SPEC §4.12, API_CONTRACT):
///
/// * [update] only remembers the latest position (cheap — called per page turn).
/// * Every [interval] (30 s) the latest position is sent together with the
///   reading seconds since the previous successful send (`readingTimeDeltaSeconds`).
/// * [flush] is also called on pause / dispose.
/// * A failed send keeps the position **and** the elapsed seconds, so the next
///   flush retries with the accumulated total (RN `accumulatedSeconds`).
/// * Seconds spent in the background are not counted ([pause]/[resume]).
class ProgressSync {
  ProgressSync({
    required ProgressSender send,
    this.interval = const Duration(seconds: 30),
    this.maxDeltaPerFlush = 600,
    this.minGap = const Duration(seconds: 10),
    DateTime Function()? now,
  })  : _send = send,
        _now = now ?? DateTime.now {
    _mark = _now();
  }

  final ProgressSender _send;
  final Duration interval;

  /// Upper bound of seconds credited for one flush (phone left open on a page).
  final int maxDeltaPerFlush;

  /// Non-final flushes closer together than this are skipped (lifecycle
  /// events can fire in bursts). `flush(force: true)` ignores it.
  final Duration minGap;
  DateTime? _lastSend;
  final DateTime Function() _now;

  ProgressPayload? _latest;
  int _carrySeconds = 0;
  late DateTime _mark;
  bool _paused = false;
  bool _flushing = false;
  Timer? _timer;
  bool _disposed = false;

  /// Starts the periodic flush.
  void start() {
    _mark = _now();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => flush());
  }

  /// Latest reader position (call on every page turn).
  void update(ProgressPayload p) {
    if (_disposed) return;
    _latest = p;
  }

  /// App went to background: send now and stop counting time.
  Future<void> pause() async {
    await flush(force: true);
    _paused = true;
  }

  /// App is back: restart the time counter.
  void resume() {
    _paused = false;
    _mark = _now();
  }

  /// Sends the latest position (if any). Safe to call concurrently.
  Future<void> flush({bool force = false}) async {
    final payload = _latest;
    if (payload == null || _flushing || _disposed) return;
    final now = _now();
    final last = _lastSend;
    if (!force && last != null && now.difference(last) < minGap) return;
    _flushing = true;
    _lastSend = now;

    var delta = _paused ? 0 : now.difference(_mark).inSeconds;
    if (delta < 0) delta = 0;
    if (delta > maxDeltaPerFlush) delta = maxDeltaPerFlush;
    final credited = _carrySeconds + delta;
    _mark = now;

    try {
      final res = await _send(payload, credited);
      if (res.isSuccess) {
        _carrySeconds = 0;
      } else {
        _carrySeconds = credited; // retry later with the accumulated time
      }
    } catch (_) {
      _carrySeconds = credited;
    } finally {
      _flushing = false;
    }
  }

  /// Final flush; no timer afterwards.
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await flush(force: true);
    _disposed = true;
  }
}
