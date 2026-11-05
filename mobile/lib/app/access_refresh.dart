import 'dart:async';

/// Decides WHEN the app re-reads the user's plan, feature access and the
/// payment switch, so an admin change reaches a running app within about a
/// minute:
///  * every [interval] (45 s) while the app is in the foreground,
///  * right away when the app comes back to the foreground ([request]),
///  * never more often than once per [minGap] (15 s),
///  * only while [isAllowed] says so (signed in) — a skipped call does not
///    count towards the 15 s gap.
class AccessRefreshScheduler {
  AccessRefreshScheduler({
    required this.isAllowed,
    required this.onRefresh,
    this.interval = const Duration(seconds: 45),
    this.minGap = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final bool Function() isAllowed;
  final void Function() onRefresh;
  final Duration interval;
  final Duration minGap;
  final DateTime Function() _now;

  Timer? _timer;
  DateTime? _last;
  bool _foreground = true;

  bool get isRunning => _timer != null;

  void start() {
    _timer ??= Timer.periodic(interval, (_) {
      if (_foreground) request();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Call from `didChangeAppLifecycleState`.
  void setForeground(bool foreground) => _foreground = foreground;

  /// Refreshes now unless signed out or the last refresh was less than
  /// [minGap] ago. Returns true when a refresh was started.
  bool request() {
    if (!isAllowed()) return false;
    final now = _now();
    final last = _last;
    if (last != null && now.difference(last) < minGap) return false;
    _last = now;
    onRefresh();
    return true;
  }
}
