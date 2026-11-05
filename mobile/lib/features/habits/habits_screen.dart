import 'habits_entry.dart' show TrialBanner;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../constants/app_colors.dart';
import '../../core/formats.dart';
import '../../core/services/routes.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/bottom_sheet_scaffold.dart';
import '../../widgets/pressable_opacity.dart';
import '../library/data/models/book.dart';
import '../library/providers/library_providers.dart';
import '../profile/widgets/settings_row.dart' show AppSwitch;
import 'habit_models.dart';
import 'habit_providers.dart';

const List<Color> _habitColors = [
  AppColors.primary500,
  AppColors.success500,
  AppColors.blue500,
  AppColors.purple500,
  AppColors.amber400,
  AppColors.error400,
];

Color habitColor(Habit h) => _habitColors[h.colorIndex % _habitColors.length];

/// Habit tracker: a Google-Calendar-style month grid (ticks and fails), today's
/// progress, streaks and statistics below. Several habits, each with its own
/// book, pages goal, days and reminders.
class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _selected; // null = all habits

  void _back() => context.canPop() ? context.pop() : context.go(AppRoutes.home);

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(habitsProvider);
    final today = dateOnly(DateTime.now());
    final habits = data.habits;
    final selected = habits.where((h) => h.id == _selected).firstOrNull;
    final shown = selected != null ? [selected] : habits;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
              child: Row(
                children: [
                  PressableOpacity(
                    pressedOpacity: 0.7,
                    semanticLabel: 'Back',
                    onTap: _back,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Ionicons.arrow_back, color: AppColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    child: Text('Habits', style: AppTypography.label(size: 22, weight: FontWeight.w700)),
                  ),
                  PressableOpacity(
                    pressedOpacity: 0.8,
                    semanticLabel: 'New habit',
                    onTap: () => showHabitEditor(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary500,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Ionicons.add, size: 18, color: AppColors.white),
                          const SizedBox(width: 4),
                          Text(
                            'New',
                            style: AppTypography.label(size: 13, weight: FontWeight.w600, color: AppColors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: habits.isEmpty
                  ? _EmptyHabits(onCreate: () => showHabitEditor(context))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                      children: [
                        const TrialBanner(),
                        // habit filter chips
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _Chip(
                                label: 'All',
                                color: AppColors.textSecondary,
                                active: _selected == null,
                                onTap: () => setState(() => _selected = null),
                              ),
                              for (final h in habits)
                                _Chip(
                                  label: h.name,
                                  color: habitColor(h),
                                  active: _selected == h.id,
                                  onTap: () => setState(() => _selected = h.id),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _MonthHeader(
                          month: _month,
                          onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1, 1)),
                          onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1, 1)),
                          onToday: () => setState(() => _month = DateTime(today.year, today.month, 1)),
                        ),
                        _CalendarGrid(
                          month: _month,
                          habits: shown,
                          data: data,
                          today: today,
                          single: selected != null,
                          onDay: (d) => _showDaySheet(d),
                        ),
                        const SizedBox(height: 18),
                        const _SectionTitle('TODAY'),
                        for (final h in habits.where((h) => h.scheduledOn(today) || (data.logOf(h.id, today)?.amount ?? 0) > 0))
                          _TodayCard(habit: h, data: data, today: today),
                        if (!habits.any((h) => h.scheduledOn(today)))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Rest day — nothing scheduled today. Reading still counts!',
                              style: AppTypography.label(size: 13, color: AppColors.textMuted),
                            ),
                          ),
                        const SizedBox(height: 14),
                        _SectionTitle(selected == null ? 'STATISTICS' : 'STATISTICS · ${selected.name.toUpperCase()}'),
                        _Stats(habits: shown, data: data, month: _month, today: today),
                        const SizedBox(height: 10),
                        for (final h in shown)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => showHabitEditor(context, existing: h),
                              icon: Icon(Ionicons.create_outline, size: 16, color: habitColor(h)),
                              label: Text(
                                'Edit "${h.name}"',
                                style: AppTypography.label(size: 13, weight: FontWeight.w600, color: habitColor(h)),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDaySheet(DateTime day) {
    showAppBottomSheet<void>(
      context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final data = ref.watch(habitsProvider);
          final ctl = ref.read(habitsProvider.notifier);
          final today = dateOnly(DateTime.now());
          final list = (_selected == null ? data.habits : data.habits.where((h) => h.id == _selected)).toList();
          return BottomSheetScaffold(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat.yMMMMEEEEd().format(day), style: AppTypography.section17),
                  const SizedBox(height: 12),
                  if (day.isAfter(today))
                    Text(
                      'This day is in the future.',
                      style: AppTypography.label(size: 13, color: AppColors.textMuted),
                    ),
                  for (final h in list) ...[
                    Builder(builder: (_) {
                      final log = data.logOf(h.id, day);
                      final st = statusOn(h, log, day, today);
                      final amount = log?.amount ?? 0;
                      final step = h.unit == GoalUnit.pages ? 1 : 60;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.alpha(habitColor(h), 0x50)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: habitColor(h), shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(h.name, style: AppTypography.label(size: 15, weight: FontWeight.w600))),
                                _StatusBadge(status: st),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  h.unit == GoalUnit.pages ? 'Pages read' : 'Minutes read',
                                  style: AppTypography.label(size: 13, color: AppColors.textSecondary),
                                ),
                                const Spacer(),
                                _Step(icon: Ionicons.remove_circle_outline, onTap: () => ctl.setAmount(h.id, day, amount - step)),
                                SizedBox(
                                  width: 64,
                                  child: Text(
                                    h.unit == GoalUnit.pages ? '$amount' : '${amount ~/ 60}',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.label(size: 18, weight: FontWeight.w700),
                                  ),
                                ),
                                _Step(icon: Ionicons.add_circle_outline, onTap: () => ctl.setAmount(h.id, day, amount + step)),
                              ],
                            ),
                            Text(
                              'Goal: ${h.goal} ${h.unit == GoalUnit.pages ? 'pages' : 'min'}',
                              style: AppTypography.label(size: 11, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _MarkButton(
                                    label: 'Done',
                                    icon: Ionicons.checkmark_circle,
                                    color: AppColors.success500,
                                    on: log?.mark == DayMark.done,
                                    onTap: () => ctl.setMark(h.id, day, log?.mark == DayMark.done ? DayMark.none : DayMark.done),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _MarkButton(
                                    label: 'Failed',
                                    icon: Ionicons.close_circle,
                                    color: AppColors.error500,
                                    on: log?.mark == DayMark.failed,
                                    onTap: () => ctl.setMark(h.id, day, log?.mark == DayMark.failed ? DayMark.none : DayMark.failed),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: AppTypography.label(size: 11, weight: FontWeight.w600, letterSpacing: 0.8, color: AppColors.textMuted),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.active, required this.onTap});

  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: PressableOpacity(
          pressedOpacity: 0.75,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.alpha(color, 0x25) : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? color : AppColors.borderDefault),
            ),
            child: Text(
              label,
              style: AppTypography.label(
                size: 13,
                weight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? color : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.onPrev, required this.onNext, required this.onToday});

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData i, String l, VoidCallback t) => PressableOpacity(
          pressedOpacity: 0.7,
          semanticLabel: l,
          onTap: t,
          child: SizedBox(width: 40, height: 40, child: Icon(i, size: 22, color: AppColors.textSecondary)),
        );
    return Row(
      children: [
        Expanded(
          child: Text(DateFormat.yMMMM().format(month), style: AppTypography.label(size: 20, weight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: onToday,
          child: Text('Today', style: AppTypography.label(size: 13, weight: FontWeight.w600, color: AppColors.primary500)),
        ),
        arrow(Ionicons.chevron_back, 'Previous month', onPrev),
        arrow(Ionicons.chevron_forward, 'Next month', onNext),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.habits,
    required this.data,
    required this.today,
    required this.single,
    required this.onDay,
  });

  final DateTime month;
  final List<Habit> habits;
  final HabitData data;
  final DateTime today;
  final bool single;
  final void Function(DateTime day) onDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final lead = first.weekday - 1; // Monday-first
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((lead + days) / 7).ceil();

    Widget cell(int index) {
      final dayNum = index - lead + 1;
      if (dayNum < 1 || dayNum > days) return const SizedBox.shrink();
      final d = DateTime(month.year, month.month, dayNum);
      final isToday = d == today;

      final statuses = [
        for (final h in habits) (h, statusOn(h, data.logOf(h.id, d), d, today)),
      ];
      final allOff = statuses.every((s) => s.$2 == DayStatus.off);

      return PressableOpacity(
        pressedOpacity: 0.7,
        onTap: () => onDay(d),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isToday ? AppColors.alpha(AppColors.primary500, 0x14) : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isToday ? AppColors.primary500 : AppColors.borderDefault),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNum',
                style: AppTypography.label(
                  size: 13,
                  weight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: allOff ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              if (single && statuses.isNotEmpty)
                _Mark(status: statuses.first.$2, color: habitColor(statuses.first.$1))
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 2,
                  runSpacing: 2,
                  children: [
                    for (final s in statuses)
                      if (s.$2 != DayStatus.off) _Dot(status: s.$2, color: habitColor(s.$1)),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (final w in kWeekdayShort)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(w, style: AppTypography.label(size: 11, color: AppColors.textMuted)),
                  ),
                ),
              ),
          ],
        ),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: AspectRatio(aspectRatio: 0.82, child: cell(r * 7 + c)),
                ),
            ],
          ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Legend(color: AppColors.success500, label: 'Done'),
            _Legend(color: AppColors.error500, label: 'Failed / missed'),
            _Legend(color: AppColors.textMuted, label: 'Upcoming'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(label, style: AppTypography.label(size: 11, color: AppColors.textMuted)),
          ],
        ),
      );
}

/// Big mark for a single-habit calendar.
class _Mark extends StatelessWidget {
  const _Mark({required this.status, required this.color});
  final DayStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case DayStatus.done:
        return const Icon(Ionicons.checkmark_circle, size: 22, color: AppColors.success500);
      case DayStatus.failed:
        return const Icon(Ionicons.close_circle, size: 22, color: AppColors.error500);
      case DayStatus.missed:
        return Icon(Ionicons.close_circle, size: 22, color: AppColors.alpha(AppColors.error500, 0x70));
      case DayStatus.pending:
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
        );
      case DayStatus.off:
        return const SizedBox(height: 22);
    }
  }
}

/// Small dot for the all-habits calendar.
class _Dot extends StatelessWidget {
  const _Dot({required this.status, required this.color});
  final DayStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fill = switch (status) {
      DayStatus.done => color,
      DayStatus.failed => AppColors.error500,
      DayStatus.missed => AppColors.alpha(AppColors.error500, 0x80),
      _ => Colors.transparent,
    };
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: status == DayStatus.pending ? color : fill, width: 1.5),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final DayStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      DayStatus.done => ('Done ✓', AppColors.success500),
      DayStatus.failed => ('Failed ✗', AppColors.error500),
      DayStatus.missed => ('Missed', AppColors.error500),
      DayStatus.pending => ('Open', AppColors.textMuted),
      DayStatus.off => ('Rest day', AppColors.textMuted),
    };
    return Text(label, style: AppTypography.label(size: 12, weight: FontWeight.w600, color: color));
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PressableOpacity(
        pressedOpacity: 0.7,
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 26, color: AppColors.primary500)),
      );
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({required this.label, required this.icon, required this.color, required this.on, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PressableOpacity(
        pressedOpacity: 0.8,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? AppColors.alpha(color, 0x25) : AppColors.elevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? color : AppColors.borderDefault),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: on ? color : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(label, style: AppTypography.label(size: 13, weight: FontWeight.w600, color: on ? color : AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.habit, required this.data, required this.today});

  final Habit habit;
  final HabitData data;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = data.logOf(habit.id, today);
    final st = statusOn(habit, log, today, today);
    final amount = log?.amount ?? 0;
    final pct = habit.goalAmount == 0 ? 0.0 : (amount / habit.goalAmount).clamp(0.0, 1.0).toDouble();
    final color = habitColor(habit);
    final ctl = ref.read(habitsProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 46, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.label(size: 15, weight: FontWeight.w600)),
                if (habit.bookTitle != null)
                  Text(habit.bookTitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.label(size: 12, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: AppColors.borderDefault, color: st == DayStatus.done ? AppColors.success500 : color),
                ),
                const SizedBox(height: 4),
                Text(progressLabel(habit, amount), style: AppTypography.label(size: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PressableOpacity(
            pressedOpacity: 0.7,
            semanticLabel: st == DayStatus.done ? 'Undo' : 'Mark done',
            onTap: () => ctl.setMark(habit.id, today, (log?.mark == DayMark.done) ? DayMark.none : DayMark.done),
            child: Icon(
              st == DayStatus.done ? Ionicons.checkmark_circle : Ionicons.checkmark_circle_outline,
              size: 34,
              color: st == DayStatus.done ? AppColors.success500 : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.habits, required this.data, required this.month, required this.today});

  final List<Habit> habits;
  final HabitData data;
  final DateTime month;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    var cur = 0, best = 0, sched = 0, done = 0, monthAmount = 0, total = 0;
    var pagesUnit = true;
    for (final h in habits) {
      final log = data.log[h.id] ?? const <String, DayLog>{};
      final c = currentStreak(h, log, today);
      final b = bestStreak(h, log, today);
      if (c > cur) cur = c;
      if (b > best) best = b;
      final m = monthStats(h, log, month, today);
      sched += m.scheduled;
      done += m.done;
      if (h.unit == GoalUnit.pages) {
        monthAmount += m.amount;
        total += totalAmount(log);
      } else {
        pagesUnit = false;
      }
    }
    final rate = sched == 0 ? 0 : (done * 100 / sched).round();

    Widget tile(String emoji, String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(value, style: AppTypography.label(size: 20, weight: FontWeight.w700, color: AppColors.primary500)),
                const SizedBox(height: 2),
                Text(label, textAlign: TextAlign.center, style: AppTypography.label(size: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        );

    return Column(
      children: [
        Row(
          children: [
            tile('🔥', '$cur', 'Current streak'),
            const SizedBox(width: 10),
            tile('🏆', '$best', 'Best streak'),
            const SizedBox(width: 10),
            tile('🎯', '$rate%', '${DateFormat.MMM().format(month)} success'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            tile('✅', '$done / $sched', 'Days done this month'),
            const SizedBox(width: 10),
            tile('📖', pagesUnit ? '$monthAmount' : '—', 'Pages this month'),
            const SizedBox(width: 10),
            tile('📚', pagesUnit ? '$total' : '—', 'Pages in total'),
          ],
        ),
      ],
    );
  }
}

class _EmptyHabits extends StatelessWidget {
  const _EmptyHabits({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🗓️', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 12),
              Text('Build a reading habit', style: AppTypography.title20),
              const SizedBox(height: 8),
              Text(
                'Pick a book, set how many pages to read on which days, and get a reminder. Days tick themselves when you reach your goal — or tick them yourself.',
                textAlign: TextAlign.center,
                style: AppTypography.label(size: 14, color: AppColors.textSecondary, lineHeight: 21),
              ),
              const SizedBox(height: 20),
              PressableOpacity(
                pressedOpacity: 0.85,
                onTap: onCreate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                  decoration: BoxDecoration(color: AppColors.primary500, borderRadius: BorderRadius.circular(12)),
                  child: Text('Create my first habit', style: AppTypography.label(size: 15, weight: FontWeight.w600, color: AppColors.white)),
                ),
              ),
            ],
          ),
        ),
      );
}

// ── create / edit ─────────────────────────────────────────────────────────────

Future<void> showHabitEditor(BuildContext context, {Habit? existing}) {
  return showAppBottomSheet<void>(context, builder: (_) => _HabitEditor(existing: existing));
}

/// Result of the book picker ("any book" = book null; a dismissed sheet = no result).
class _BookPick {
  const _BookPick(this.book);
  final Book? book;
}

class _HabitEditor extends ConsumerStatefulWidget {
  const _HabitEditor({this.existing});
  final Habit? existing;

  @override
  ConsumerState<_HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends ConsumerState<_HabitEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? 'Daily reading');
  late int _goal = widget.existing?.goal ?? 10;
  late GoalUnit _unit = widget.existing?.unit ?? GoalUnit.pages;
  late Set<int> _days = {...(widget.existing?.days ?? const {1, 2, 3, 4, 5})};
  late bool _remind = widget.existing?.hasReminder ?? true;
  late int _time = (widget.existing?.reminderMinutes ?? -1) >= 0 ? widget.existing!.reminderMinutes : 20 * 60;
  late bool _nudge = widget.existing?.nudge ?? true;
  String? _bookId;
  String? _bookTitle;

  @override
  void initState() {
    super.initState();
    _bookId = widget.existing?.bookId;
    _bookTitle = widget.existing?.bookTitle;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickBook() async {
    final books = (ref.read(libraryProvider).valueOrNull?.books ?? const <Book>[])
        .where((b) => b.kind == ViewerKind.epub || b.kind == ViewerKind.pdf)
        .toList();
    final picked = await showAppBottomSheet<_BookPick>(
      context,
      builder: (ctx) => BottomSheetScaffold(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Which book?', style: AppTypography.section17),
              const SizedBox(height: 6),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Any book I read', style: AppTypography.label(size: 15)),
                onTap: () => Navigator.of(ctx).pop(const _BookPick(null)),
              ),
              for (final b in books)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.label(size: 15)),
                  subtitle: b.author.isEmpty ? null : Text(b.author, style: AppTypography.label(size: 12, color: AppColors.textMuted)),
                  onTap: () => Navigator.of(ctx).pop(_BookPick(b)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return; // sheet dismissed: keep the current choice
    setState(() {
      _bookId = picked.book?.id;
      _bookTitle = picked.book?.title;
    });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _time ~/ 60, minute: _time % 60),
    );
    if (t != null) setState(() => _time = t.hour * 60 + t.minute);
  }

  void _save() {
    final ctl = ref.read(habitsProvider.notifier);
    final reminder = _remind ? _time : -1;
    final e = widget.existing;
    if (e == null) {
      ctl.addHabit(
        name: _name.text,
        goal: _goal,
        unit: _unit,
        bookId: _bookId,
        bookTitle: _bookTitle,
        days: _days,
        reminderMinutes: reminder,
        nudge: _nudge,
      );
      AppToast.success('Habit created!');
    } else {
      ctl.updateHabit(e.copyWith(
        name: _name.text.trim().isEmpty ? e.name : _name.text.trim(),
        goal: _goal,
        unit: _unit,
        bookId: _bookId,
        bookTitle: _bookTitle,
        clearBook: _bookId == null,
        days: _days.isEmpty ? e.days : _days,
        reminderMinutes: reminder,
        nudge: _nudge,
      ));
      AppToast.success('Habit saved.');
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final unitLabel = _unit == GoalUnit.pages ? 'pages' : 'minutes';

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(t, style: AppTypography.label(size: 11, weight: FontWeight.w600, letterSpacing: 0.8, color: AppColors.textMuted)),
        );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: kb),
      child: BottomSheetScaffold(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.existing == null ? 'New habit' : 'Edit habit', style: AppTypography.section17),
              label('NAME'),
              TextField(
                controller: _name,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: AppColors.primary500,
                style: AppTypography.body15,
                decoration: const InputDecoration(counterText: ''),
              ),
              label('BOOK'),
              PressableOpacity(
                pressedOpacity: 0.8,
                onTap: _pickBook,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _bookTitle ?? 'Any book I read',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label(size: 15),
                        ),
                      ),
                      const Icon(Ionicons.chevron_down, size: 18, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              label('DAILY GOAL'),
              Row(
                children: [
                  _Step(icon: Ionicons.remove_circle_outline, onTap: () => setState(() => _goal = (_goal - (_unit == GoalUnit.pages ? 1 : 5)).clamp(1, 999).toInt())),
                  SizedBox(
                    width: 64,
                    child: Text('$_goal', textAlign: TextAlign.center, style: AppTypography.label(size: 24, weight: FontWeight.w700)),
                  ),
                  _Step(icon: Ionicons.add_circle_outline, onTap: () => setState(() => _goal = (_goal + (_unit == GoalUnit.pages ? 1 : 5)).clamp(1, 999).toInt())),
                  const Spacer(),
                  _Chip(
                    label: 'Pages',
                    color: AppColors.primary500,
                    active: _unit == GoalUnit.pages,
                    onTap: () => setState(() {
                      _unit = GoalUnit.pages;
                      _goal = 10;
                    }),
                  ),
                  _Chip(
                    label: 'Minutes',
                    color: AppColors.primary500,
                    active: _unit == GoalUnit.minutes,
                    onTap: () => setState(() {
                      _unit = GoalUnit.minutes;
                      _goal = 20;
                    }),
                  ),
                ],
              ),
              Text('$unitLabel per scheduled day', style: AppTypography.label(size: 12, color: AppColors.textMuted)),
              label('DAYS'),
              Row(
                children: [
                  for (var i = 1; i <= 7; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: PressableOpacity(
                          pressedOpacity: 0.8,
                          semanticLabel: kWeekdayShort[i - 1],
                          onTap: () => setState(() {
                            if (_days.contains(i)) {
                              if (_days.length > 1) _days.remove(i);
                            } else {
                              _days.add(i);
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _days.contains(i) ? AppColors.alpha(AppColors.primary500, 0x25) : AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _days.contains(i) ? AppColors.primary500 : AppColors.borderDefault),
                            ),
                            child: Text(
                              kWeekdayShort[i - 1].substring(0, 1),
                              style: AppTypography.label(
                                size: 13,
                                weight: FontWeight.w600,
                                color: _days.contains(i) ? AppColors.primary500 : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _days = {1, 2, 3, 4, 5}),
                    child: Text('Mon–Fri', style: AppTypography.label(size: 12, color: AppColors.primary500)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _days = {1, 2, 3, 4, 5, 6, 7}),
                    child: Text('Every day', style: AppTypography.label(size: 12, color: AppColors.primary500)),
                  ),
                ],
              ),
              label('REMINDERS'),
              Row(
                children: [
                  Expanded(child: Text('Remind me to read', style: AppTypography.label(size: 15))),
                  if (_remind)
                    TextButton(
                      onPressed: _pickTime,
                      child: Text(timeLabel(_time), style: AppTypography.label(size: 15, weight: FontWeight.w700, color: AppColors.primary500)),
                    ),
                  AppSwitch(value: _remind, onChanged: (v) => setState(() => _remind = v)),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text("Evening nudge (9 pm) if I haven't finished", style: AppTypography.label(size: 14, color: AppColors.textSecondary)),
                  ),
                  AppSwitch(value: _nudge, onChanged: (v) => setState(() => _nudge = v)),
                ],
              ),
              const SizedBox(height: 18),
              PressableOpacity(
                pressedOpacity: 0.85,
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.primary500, borderRadius: BorderRadius.circular(12)),
                  child: Text('Save', style: AppTypography.label(size: 15, weight: FontWeight.w600, color: AppColors.white)),
                ),
              ),
              if (widget.existing != null)
                TextButton(
                  onPressed: () {
                    ref.read(habitsProvider.notifier).deleteHabit(widget.existing!.id);
                    Navigator.of(context).pop();
                  },
                  child: Text('Delete habit', style: AppTypography.label(size: 14, weight: FontWeight.w600, color: AppColors.error500)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
