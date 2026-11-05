import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/features/habits/habit_models.dart';

Habit _h({int goal = 10, Set<int> days = const {1, 2, 3, 4, 5}, DateTime? created, GoalUnit unit = GoalUnit.pages}) =>
    Habit(
      id: 'h1',
      name: 'Read',
      goal: goal,
      unit: unit,
      days: days,
      createdAt: created ?? DateTime(2026, 10, 1), // a Thursday
    );

DayLog _l(int a, [DayMark m = DayMark.none]) => DayLog(amount: a, mark: m);

String _k(DateTime d) => habitDayKey(d);

void main() {
  // 2026-10-05 is a Monday, 10-10 a Saturday, 10-11 a Sunday.
  final mon = DateTime(2026, 10, 5);
  final tue = DateTime(2026, 10, 6);
  final sat = DateTime(2026, 10, 10);

  group('statusOn', () {
    test('goal reached auto-ticks; manual mark wins', () {
      final h = _h();
      expect(statusOn(h, _l(10), mon, tue), DayStatus.done);
      expect(statusOn(h, _l(3, DayMark.done), mon, tue), DayStatus.done);
      expect(statusOn(h, _l(50, DayMark.failed), mon, tue), DayStatus.failed);
    });

    test('past scheduled day without a tick is missed, today is pending', () {
      final h = _h();
      expect(statusOn(h, _l(3), mon, tue), DayStatus.missed);
      expect(statusOn(h, null, tue, tue), DayStatus.pending);
      expect(statusOn(h, null, DateTime(2026, 10, 8), tue), DayStatus.pending); // future
    });

    test('rest days and days before the habit existed are "off"', () {
      final h = _h();
      expect(statusOn(h, null, sat, DateTime(2026, 10, 12)), DayStatus.off);
      expect(statusOn(h, null, DateTime(2026, 9, 28), tue), DayStatus.off);
      // but reading on a rest day still ticks it (bonus)
      expect(statusOn(h, _l(12), sat, DateTime(2026, 10, 12)), DayStatus.done);
    });

    test('minute goals compare seconds', () {
      final h = _h(goal: 20, unit: GoalUnit.minutes);
      expect(h.goalAmount, 1200);
      expect(statusOn(h, _l(1199), mon, tue), DayStatus.missed);
      expect(statusOn(h, _l(1200), mon, tue), DayStatus.done);
    });
  });

  group('streaks', () {
    test('current streak skips rest days and an open today', () {
      final h = _h(created: DateTime(2026, 9, 28)); // Monday
      final log = {
        _k(DateTime(2026, 9, 28)): _l(10), // Mon
        _k(DateTime(2026, 9, 29)): _l(10), // Tue
        _k(DateTime(2026, 9, 30)): _l(10), // Wed
        _k(DateTime(2026, 10, 1)): _l(10), // Thu
        _k(DateTime(2026, 10, 2)): _l(10), // Fri
        // weekend off
        _k(DateTime(2026, 10, 5)): _l(10), // Mon
      };
      // today = Tue 6 Oct, still open: streak = 6 (Mon-Fri + Mon)
      expect(currentStreak(h, log, tue), 6);
      // a missed Tuesday breaks it once the day is over
      expect(currentStreak(h, log, DateTime(2026, 10, 7)), 0);
    });

    test('failed mark breaks the streak; best streak is remembered', () {
      final h = _h(created: DateTime(2026, 9, 28));
      final log = {
        _k(DateTime(2026, 9, 28)): _l(10),
        _k(DateTime(2026, 9, 29)): _l(10),
        _k(DateTime(2026, 9, 30)): _l(10),
        _k(DateTime(2026, 10, 1)): _l(0, DayMark.failed),
        _k(DateTime(2026, 10, 2)): _l(10),
        _k(DateTime(2026, 10, 5)): _l(10),
      };
      final today = DateTime(2026, 10, 6);
      expect(bestStreak(h, log, today), 3);
      expect(currentStreak(h, log, today), 2);
    });

    test('no logs = no streak', () {
      expect(currentStreak(_h(), const {}, tue), 0);
      expect(bestStreak(_h(), const {}, tue), 0);
    });
  });

  group('month stats', () {
    test('counts scheduled days up to today, ignores the open day', () {
      final h = _h(created: DateTime(2026, 10, 1));
      final log = {
        _k(DateTime(2026, 10, 1)): _l(10),
        _k(DateTime(2026, 10, 2)): _l(4),
        _k(DateTime(2026, 10, 5)): _l(12),
      };
      final m = monthStats(h, log, DateTime(2026, 10, 1), tue);
      // Thu 1, Fri 2, Mon 5 are over; Tue 6 is open
      expect(m.scheduled, 3);
      expect(m.done, 2);
      expect(m.amount, 26);
      expect(m.rate, closeTo(2 / 3, 1e-9));
    });
  });

  group('storage', () {
    test('encode/decode round trip and garbage tolerance', () {
      final data = HabitData(
        habits: [
          Habit(
            id: 'a',
            name: 'Think and Grow Rich',
            goal: 15,
            bookId: 'b1',
            bookTitle: 'Think and Grow Rich',
            days: const {1, 3, 5},
            reminderMinutes: 20 * 60 + 30,
            nudge: false,
            colorIndex: 2,
            createdAt: DateTime(2026, 10, 1),
          ),
        ],
        log: {
          'a': {
            '2026-10-05': const DayLog(amount: 15, mark: DayMark.done),
            '2026-10-06': const DayLog(mark: DayMark.failed),
          },
        },
      );
      final back = HabitData.decode(data.encode());
      final h = back.habits.single;
      expect(h.name, 'Think and Grow Rich');
      expect(h.days, {1, 3, 5});
      expect(h.reminderMinutes, 1230);
      expect(h.nudge, isFalse);
      expect(h.bookId, 'b1');
      expect(back.log['a']!['2026-10-05']!.amount, 15);
      expect(back.log['a']!['2026-10-06']!.mark, DayMark.failed);
      expect(HabitData.decode('not json').habits, isEmpty);
      expect(HabitData.decode(null).habits, isEmpty);
    });

    test('labels', () {
      expect(timeLabel(20 * 60 + 5), '20:05');
      expect(progressLabel(_h(goal: 20), 12), '12 / 20 pages');
      expect(progressLabel(_h(goal: 20, unit: GoalUnit.minutes), 600), '10 / 20 min');
    });
  });
}
