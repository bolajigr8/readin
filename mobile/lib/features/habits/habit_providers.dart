import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/doc_syncer.dart';
import '../auth/providers/auth_providers.dart';
import '../features/feature_models.dart';
import '../features/features_provider.dart';
import 'habit_alarms.dart';
import 'habit_models.dart';

const String _kHabits = '@readin/habits_v1';

/// Habits + their daily logs, kept on the phone (works offline).
class HabitsNotifier extends StateNotifier<HabitData> {
  HabitsNotifier(this._ref, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(HabitData.decode(_ref.read(storageServiceProvider).readString(_kHabits))) {
    _syncer = DocSyncer(
      api: _ref.read(apiClientProvider),
      storage: _ref.read(storageServiceProvider),
      key: 'habits',
      readLocal: () => state.encode(),
      isLocalEmpty: () => state.habits.isEmpty,
      applyRemote: _applyRemote,
      merge: (a, b) => mergeHabitData(HabitData.decode(a), HabitData.decode(b)).encode(),
      enabled: () => _ref.read(authProvider).isAuthenticated && _allowed,
    );
    unawaited(HabitAlarms.sync(_alarmData(), now: _now()));
  }

  final Ref _ref;
  final DateTime Function() _now;
  late final DocSyncer _syncer;

  /// The habit tracker is a premium/trial feature — this is the user's access.
  bool get _allowed => _ref.read(habitsAccessProvider).allowed;

  /// Nothing is scheduled (no reminders) once the trial is over.
  HabitData _alarmData() => _allowed ? state : const HabitData();

  @override
  void dispose() {
    _syncer.dispose();
    super.dispose();
  }

  void _persist(HabitData d) =>
      _ref.read(storageServiceProvider).writeString(_kHabits, d.encode());

  void _applyRemote(String json) {
    state = HabitData.decode(json);
    _persist(state);
    unawaited(HabitAlarms.sync(_alarmData(), now: _now()));
  }

  /// Download + merge with the server copy.
  Future<void> pull() => _syncer.pull();

  /// The access changed (trial started / ended, premium, admin grant…).
  void onAccessChanged() {
    unawaited(HabitAlarms.sync(_alarmData(), now: _now()));
    if (_allowed) unawaited(_syncer.pull());
  }

  /// Sign-out: the next account must not see (or upload) this one's data.
  void clearLocal() {
    state = const HabitData();
    _persist(state);
    unawaited(_ref.read(storageServiceProvider).writeInt('@readin/sync_v_habits', 0));
    unawaited(HabitAlarms.sync(const HabitData(), now: _now()));
  }

  void _save(HabitData d, {bool resync = true}) {
    state = d;
    _persist(d);
    if (resync) unawaited(HabitAlarms.sync(_alarmData(), now: _now()));
    _syncer.markChanged();
  }

  Habit addHabit({
    required String name,
    required int goal,
    GoalUnit unit = GoalUnit.pages,
    String? bookId,
    String? bookTitle,
    Set<int> days = const {1, 2, 3, 4, 5},
    int reminderMinutes = -1,
    bool nudge = true,
  }) {
    final h = Habit(
      id: _now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Daily reading' : name.trim(),
      goal: goal < 1 ? 1 : goal,
      unit: unit,
      bookId: bookId,
      bookTitle: bookTitle,
      days: days.isEmpty ? const {1, 2, 3, 4, 5} : days,
      reminderMinutes: reminderMinutes,
      nudge: nudge,
      colorIndex: state.habits.length % 6,
      createdAt: dateOnly(_now()),
    );
    _save(HabitData(habits: [...state.habits, h], log: state.log));
    if (h.hasReminder || h.nudge) unawaited(HabitAlarms.askPermission());
    return h;
  }

  void updateHabit(Habit h) => _save(HabitData(
        habits: [for (final x in state.habits) x.id == h.id ? h : x],
        log: state.log,
      ));

  void deleteHabit(String id) {
    final log = {...state.log}..remove(id);
    _save(HabitData(habits: state.habits.where((h) => h.id != id).toList(), log: log));
  }

  DayLog _log(String id, DateTime day) => state.logOf(id, day) ?? const DayLog();

  void _setLog(String id, DateTime day, DayLog l) {
    final byDay = {...(state.log[id] ?? const <String, DayLog>{})};
    final key = habitDayKey(day);
    if (l.amount == 0 && l.mark == DayMark.none) {
      byDay.remove(key);
    } else {
      byDay[key] = l;
    }
    _save(HabitData(habits: state.habits, log: {...state.log, id: byDay}));
  }

  /// Tick / fail / clear a day by hand.
  void setMark(String habitId, DateTime day, DayMark mark) =>
      _setLog(habitId, day, _log(habitId, day).copyWith(mark: mark));

  /// Edit the logged pages (or seconds) of a day.
  void setAmount(String habitId, DateTime day, int amount) =>
      _setLog(habitId, day, _log(habitId, day).copyWith(amount: amount < 0 ? 0 : amount));

  bool _matches(Habit h, String? bookId) => h.bookId == null || h.bookId == bookId;

  /// Pages turned while reading [bookId] — feeds every matching pages-habit.
  void addPagesRead(String? bookId, int pages) {
    if (pages <= 0 || !_allowed) return;
    final today = dateOnly(_now());
    var log = state.log;
    var changed = false;
    var becameDone = false;
    for (final h in state.habits.where((h) => h.unit == GoalUnit.pages && _matches(h, bookId))) {
      final before = _log(h.id, today);
      final wasDone = statusOn(h, before, today, today) == DayStatus.done;
      final after = before.copyWith(amount: before.amount + pages);
      log = {
        ...log,
        h.id: {...(log[h.id] ?? const <String, DayLog>{}), habitDayKey(today): after},
      };
      changed = true;
      if (!wasDone && statusOn(h, after, today, today) == DayStatus.done) becameDone = true;
    }
    if (changed) _save(HabitData(habits: state.habits, log: log), resync: becameDone);
  }

  /// Seconds read — feeds every matching minutes-habit.
  void addSecondsRead(String? bookId, int seconds) {
    if (seconds <= 0 || !_allowed) return;
    final today = dateOnly(_now());
    var log = state.log;
    var changed = false;
    var becameDone = false;
    for (final h in state.habits.where((h) => h.unit == GoalUnit.minutes && _matches(h, bookId))) {
      final before = _log(h.id, today);
      final wasDone = statusOn(h, before, today, today) == DayStatus.done;
      final after = before.copyWith(amount: before.amount + seconds);
      log = {
        ...log,
        h.id: {...(log[h.id] ?? const <String, DayLog>{}), habitDayKey(today): after},
      };
      changed = true;
      if (!wasDone && statusOn(h, after, today, today) == DayStatus.done) becameDone = true;
    }
    if (changed) _save(HabitData(habits: state.habits, log: log), resync: becameDone);
  }
}

final habitsProvider = StateNotifierProvider<HabitsNotifier, HabitData>((ref) {
  final n = HabitsNotifier(ref);
  // When the access changes (trial started / over, premium, admin gift) the
  // reminders and the cloud copy follow.
  ref.listen<FeatureAccess>(habitsAccessProvider, (prev, next) {
    if (prev == null || prev.state != next.state) n.onAccessChanged();
  });
  return n;
});
