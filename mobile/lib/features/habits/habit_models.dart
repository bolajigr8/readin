import 'dart:convert';

import 'package:intl/intl.dart';

/// Manual override of a day (the user can tick or fail a day by hand).
enum DayMark { none, done, failed }

/// What a day looks like in the calendar.
enum DayStatus {
  /// Goal reached (auto) or ticked by hand.
  done,

  /// Marked as failed by hand.
  failed,

  /// A past scheduled day without a tick.
  missed,

  /// Today (not finished yet) or a future scheduled day.
  pending,

  /// Not a scheduled day (and nothing logged), or before the habit existed.
  off,
}

enum GoalUnit { pages, minutes }

String habitDayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// A reading habit: "10 pages of Think and Grow Rich on weekdays at 8 pm".
class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.goal,
    required this.createdAt,
    this.unit = GoalUnit.pages,
    this.bookId,
    this.bookTitle,
    this.days = const {1, 2, 3, 4, 5},
    this.reminderMinutes = -1,
    this.nudge = true,
    this.colorIndex = 0,
  });

  final String id;
  final String name;

  /// Pages (or minutes) to read on a scheduled day.
  final int goal;
  final GoalUnit unit;

  /// null = any book counts.
  final String? bookId;
  final String? bookTitle;

  /// ISO weekdays: 1 = Monday … 7 = Sunday. Default Monday–Friday.
  final Set<int> days;

  /// Reminder time as minutes after midnight, -1 = no reminder.
  final int reminderMinutes;

  /// Evening "don't break your streak" nudge.
  final bool nudge;
  final int colorIndex;
  final DateTime createdAt;

  bool get hasReminder => reminderMinutes >= 0;
  bool scheduledOn(DateTime d) => days.contains(d.weekday);

  /// Goal in the units stored in the log (pages, or SECONDS for minutes).
  int get goalAmount => unit == GoalUnit.pages ? goal : goal * 60;

  Habit copyWith({
    String? name,
    int? goal,
    GoalUnit? unit,
    String? bookId,
    String? bookTitle,
    bool clearBook = false,
    Set<int>? days,
    int? reminderMinutes,
    bool? nudge,
    int? colorIndex,
  }) =>
      Habit(
        id: id,
        name: name ?? this.name,
        goal: goal ?? this.goal,
        unit: unit ?? this.unit,
        bookId: clearBook ? null : (bookId ?? this.bookId),
        bookTitle: clearBook ? null : (bookTitle ?? this.bookTitle),
        days: days ?? this.days,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        nudge: nudge ?? this.nudge,
        colorIndex: colorIndex ?? this.colorIndex,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'goal': goal,
        'unit': unit.name,
        if (bookId != null) 'bookId': bookId,
        if (bookTitle != null) 'bookTitle': bookTitle,
        'days': days.toList()..sort(),
        'reminder': reminderMinutes,
        'nudge': nudge,
        'color': colorIndex,
        'created': createdAt.toIso8601String(),
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: '${j['id']}',
        name: '${j['name']}',
        goal: (j['goal'] as num?)?.toInt() ?? 10,
        unit: j['unit'] == 'minutes' ? GoalUnit.minutes : GoalUnit.pages,
        bookId: j['bookId'] as String?,
        bookTitle: j['bookTitle'] as String?,
        days: {
          for (final d in (j['days'] as List? ?? const [1, 2, 3, 4, 5])) (d as num).toInt(),
        },
        reminderMinutes: (j['reminder'] as num?)?.toInt() ?? -1,
        nudge: j['nudge'] != false,
        colorIndex: (j['color'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse('${j['created']}') ?? DateTime.now(),
      );
}

/// What was logged on one day for one habit.
class DayLog {
  const DayLog({this.amount = 0, this.mark = DayMark.none});

  /// Pages read (or seconds read for minute-goals).
  final int amount;
  final DayMark mark;

  DayLog copyWith({int? amount, DayMark? mark}) =>
      DayLog(amount: amount ?? this.amount, mark: mark ?? this.mark);
}

/// All habits plus their day logs: `log[habitId][yyyy-MM-dd]`.
class HabitData {
  const HabitData({this.habits = const [], this.log = const {}});

  final List<Habit> habits;
  final Map<String, Map<String, DayLog>> log;

  DayLog? logOf(String habitId, DateTime day) => log[habitId]?[habitDayKey(day)];

  String encode() => jsonEncode({
        'habits': habits.map((h) => h.toJson()).toList(),
        'log': {
          for (final e in log.entries)
            e.key: {
              for (final d in e.value.entries)
                d.key: {
                  if (d.value.amount > 0) 'a': d.value.amount,
                  if (d.value.mark != DayMark.none) 'm': d.value.mark.name,
                },
            },
        },
      });

  static HabitData decode(String? raw) {
    if (raw == null || raw.isEmpty) return const HabitData();
    try {
      final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final habits = [
        for (final h in (j['habits'] as List? ?? const []))
          Habit.fromJson(Map<String, dynamic>.from(h as Map)),
      ];
      final log = <String, Map<String, DayLog>>{};
      Map<String, dynamic>.from(j['log'] as Map? ?? const {}).forEach((id, days) {
        final m = <String, DayLog>{};
        Map<String, dynamic>.from(days as Map).forEach((day, v) {
          final e = Map<String, dynamic>.from(v as Map);
          m[day] = DayLog(
            amount: (e['a'] as num?)?.toInt() ?? 0,
            mark: DayMark.values.firstWhere((x) => x.name == e['m'], orElse: () => DayMark.none),
          );
        });
        log[id] = m;
      });
      return HabitData(habits: habits, log: log);
    } catch (_) {
      return const HabitData();
    }
  }
}

/// Union of two copies of the habit data (used by cloud sync, never loses a day):
/// habits by id (the local copy wins on a clash); per day the larger amount and
/// the local mark (falling back to the server's).
HabitData mergeHabitData(HabitData local, HabitData server) {
  final habits = [...local.habits];
  for (final h in server.habits) {
    if (!habits.any((x) => x.id == h.id)) habits.add(h);
  }
  final log = <String, Map<String, DayLog>>{};
  final ids = {...local.log.keys, ...server.log.keys};
  for (final id in ids) {
    final l = local.log[id] ?? const <String, DayLog>{};
    final s = server.log[id] ?? const <String, DayLog>{};
    final days = <String, DayLog>{};
    for (final d in {...l.keys, ...s.keys}) {
      final a = l[d];
      final b = s[d];
      if (a == null) {
        days[d] = b!;
      } else if (b == null) {
        days[d] = a;
      } else {
        days[d] = DayLog(
          amount: a.amount >= b.amount ? a.amount : b.amount,
          mark: a.mark != DayMark.none ? a.mark : b.mark,
        );
      }
    }
    log[id] = days;
  }
  return HabitData(habits: habits, log: log);
}

// ── pure logic (unit-tested) ───────────────────────────────────────────────────

/// Status of [day] for [habit]: a manual mark wins; reaching the goal
/// auto-ticks; otherwise past scheduled days are "missed".
DayStatus statusOn(Habit habit, DayLog? log, DateTime day, DateTime today) {
  final d = dateOnly(day);
  final t = dateOnly(today);
  final amount = log?.amount ?? 0;
  final mark = log?.mark ?? DayMark.none;

  if (mark == DayMark.done) return DayStatus.done;
  if (mark == DayMark.failed) return DayStatus.failed;
  if (amount >= habit.goalAmount && habit.goalAmount > 0) return DayStatus.done;
  if (d.isBefore(dateOnly(habit.createdAt))) return DayStatus.off;
  if (!habit.scheduledOn(d)) return DayStatus.off;
  if (d.isAfter(t) || d == t) return DayStatus.pending;
  return DayStatus.missed;
}

/// Consecutive scheduled days completed, counted back from [today]
/// (today still being open does not break the streak).
int currentStreak(Habit habit, Map<String, DayLog> log, DateTime today) {
  var streak = 0;
  var d = dateOnly(today);
  final start = dateOnly(habit.createdAt);
  for (var i = 0; i < 800 && !d.isBefore(start); i++) {
    final s = statusOn(habit, log[habitDayKey(d)], d, today);
    if (s == DayStatus.done) {
      streak++;
    } else if (s == DayStatus.failed || s == DayStatus.missed) {
      break;
    } // pending (today) / off (rest day): skip
    d = d.subtract(const Duration(days: 1));
  }
  return streak;
}

int bestStreak(Habit habit, Map<String, DayLog> log, DateTime today) {
  var best = 0, run = 0;
  var d = dateOnly(habit.createdAt);
  final end = dateOnly(today);
  for (var i = 0; i < 1500 && !d.isAfter(end); i++) {
    final s = statusOn(habit, log[habitDayKey(d)], d, today);
    if (s == DayStatus.done) {
      run++;
      if (run > best) best = run;
    } else if (s == DayStatus.failed || s == DayStatus.missed) {
      run = 0;
    }
    d = d.add(const Duration(days: 1));
  }
  return best;
}

class MonthStats {
  const MonthStats({required this.scheduled, required this.done, required this.amount});

  /// Scheduled days up to today in the month.
  final int scheduled;
  final int done;

  /// Pages (or seconds) logged in the month.
  final int amount;

  double get rate => scheduled == 0 ? 0 : done / scheduled;
}

MonthStats monthStats(Habit habit, Map<String, DayLog> log, DateTime month, DateTime today) {
  var scheduled = 0, done = 0, amount = 0;
  final first = DateTime(month.year, month.month, 1);
  final last = DateTime(month.year, month.month + 1, 0);
  final t = dateOnly(today);
  final created = dateOnly(habit.createdAt);
  for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
    final l = log[habitDayKey(d)];
    amount += l?.amount ?? 0;
    if (d.isAfter(t) || d.isBefore(created) || !habit.scheduledOn(d)) continue;
    final s = statusOn(habit, l, d, today);
    if (s == DayStatus.pending) continue; // today is still open
    scheduled++;
    if (s == DayStatus.done) done++;
  }
  return MonthStats(scheduled: scheduled, done: done, amount: amount);
}

int totalAmount(Map<String, DayLog> log) => log.values.fold(0, (n, l) => n + l.amount);

/// "12 / 20 pages" or "8 / 20 min".
String progressLabel(Habit h, int amount) {
  if (h.unit == GoalUnit.pages) return '$amount / ${h.goal} pages';
  return '${amount ~/ 60} / ${h.goal} min';
}

/// "20:30" style from minutes after midnight.
String timeLabel(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

const List<String> kWeekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
