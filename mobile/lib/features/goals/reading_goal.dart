import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/storage_service.dart';
import '../../widgets/app_toast.dart';
import '../auth/providers/auth_providers.dart';

/// `yyyy-MM-dd` key of [d] (local time).
String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Consecutive days with at least [minSeconds] of reading, counted back from
/// today. Today may still be empty (the streak is then counted from yesterday
/// so it does not show 0 first thing in the morning).
int computeStreak(int Function(DateTime day) secondsOn, DateTime today,
    {int minSeconds = 60, int maxDays = 365}) {
  var streak = 0;
  var day = DateTime(today.year, today.month, today.day);
  if (secondsOn(day) < minSeconds) day = day.subtract(const Duration(days: 1));
  for (var i = 0; i < maxDays; i++) {
    if (secondsOn(day) >= minSeconds) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }
  return streak;
}

class ReadingGoalState {
  const ReadingGoalState({
    required this.goalMinutes,
    required this.todaySeconds,
    required this.last7,
    required this.streak,
    required this.weekdays,
  });

  final int goalMinutes;
  final int todaySeconds;

  /// Seconds per day, oldest → today (7 values).
  final List<int> last7;

  /// Weekday letters matching [last7] ("M", "T", …).
  final List<String> weekdays;
  final int streak;

  int get todayMinutes => todaySeconds ~/ 60;
  double get progress =>
      goalMinutes <= 0 ? 0 : (todaySeconds / (goalMinutes * 60)).clamp(0.0, 1.0).toDouble();
  bool get goalReached => goalMinutes > 0 && todaySeconds >= goalMinutes * 60;
}

/// Local daily reading goal + streak (data stays on the phone).
class ReadingGoalNotifier extends StateNotifier<ReadingGoalState> {
  ReadingGoalNotifier(this._storage, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(_build(_storage, (now ?? DateTime.now)()));

  final StorageService _storage;
  final DateTime Function() _now;

  static ReadingGoalState _build(StorageService s, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    int on(DateTime d) => s.readSecondsOn(dayKey(d));
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return ReadingGoalState(
      goalMinutes: s.dailyGoalMinutes,
      todaySeconds: on(today),
      last7: [for (final d in days) on(d)],
      weekdays: [for (final d in days) letters[d.weekday - 1]],
      streak: computeStreak(on, today),
    );
  }

  /// Re-read everything (call when the screen appears: handles midnight).
  void refresh() => state = _build(_storage, _now());

  /// Adds [seconds] of reading to today.
  void add(int seconds) {
    if (seconds <= 0) return;
    final key = dayKey(_now());
    final before = state.goalReached;
    final hour = _now().hour;
    if (hour >= 22 || hour < 5) {
      _storage.writeInt('@readin/night_seconds', _storage.readInt('@readin/night_seconds') + seconds);
    }
    _storage.setReadSecondsOn(key, _storage.readSecondsOn(key) + seconds);
    state = _build(_storage, _now());
    if (!before && state.goalReached) {
      _storage.writeInt('@readin/goal_days', _storage.readInt('@readin/goal_days') + 1);
      AppToast.success('Daily reading goal reached! 🎉');
    }
  }

  void setGoal(int minutes) {
    final m = minutes.clamp(5, 240).toInt();
    _storage.setDailyGoalMinutes(m);
    state = _build(_storage, _now());
  }
}

final readingGoalProvider =
    StateNotifierProvider<ReadingGoalNotifier, ReadingGoalState>(
  (ref) => ReadingGoalNotifier(ref.watch(storageServiceProvider)),
);
