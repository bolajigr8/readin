import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../constants/app_colors.dart';
import '../../core/services/routes.dart';
import '../../theme/app_typography.dart';
import '../../widgets/pressable_opacity.dart';
import '../features/feature_models.dart';
import '../features/features_provider.dart';
import 'habit_models.dart';
import 'habit_providers.dart';
import 'habits_screen.dart' show habitColor;

/// Home card: today's habits with progress (tap → Habits screen).
class HabitsHomeCard extends ConsumerWidget {
  const HabitsHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(habitsProvider);
    final access = ref.watch(habitsAccessProvider);
    final today = dateOnly(DateTime.now());
    final todays = data.habits.where((h) => h.scheduledOn(today)).toList();
    final locked = access.state == AccessState.expired ||
        access.state == AccessState.locked ||
        access.state == AccessState.disabled;
    final daysLeft = access.daysLeft();

    return PressableOpacity(
      pressedOpacity: 0.85,
      onTap: () => context.push(AppRoutes.habits),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🗓️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    locked
                        ? 'Habit tracker · trial ended'
                        : (data.habits.isEmpty ? 'Build a reading habit' : "Today's habits"),
                    style: AppTypography.label(size: 15, weight: FontWeight.w600),
                  ),
                ),
                if (access.state == AccessState.trial && daysLeft != null)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.alpha(daysLeft <= 3 ? AppColors.error400 : AppColors.amber400, 0x25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$daysLeft days free',
                      style: AppTypography.label(
                        size: 11,
                        weight: FontWeight.w600,
                        color: daysLeft <= 3 ? AppColors.error400 : AppColors.amber400,
                      ),
                    ),
                  ),
                const Icon(Ionicons.chevron_forward, size: 16, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: 8),
            if (locked)
              Text(
                'Your free trial is over. Get Premium to keep tracking — your habits are saved.',
                style: AppTypography.label(size: 13, color: AppColors.textSecondary, lineHeight: 19),
              )
            else if (access.state == AccessState.trialAvailable)
              Text(
                'Try the habit tracker free for 14 days — daily goals, calendar and reminders.',
                style: AppTypography.label(size: 13, color: AppColors.textSecondary, lineHeight: 19),
              )
            else if (data.habits.isEmpty)
              Text(
                'Pick a book, set a pages goal and get a daily reminder.',
                style: AppTypography.label(size: 13, color: AppColors.textSecondary, lineHeight: 19),
              )
            else if (todays.isEmpty)
              Text('Rest day — enjoy! Tap to see your calendar.',
                  style: AppTypography.label(size: 13, color: AppColors.textSecondary))
            else
              for (final h in todays.take(3)) _Row(habit: h, data: data, today: today),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.habit, required this.data, required this.today});

  final Habit habit;
  final HabitData data;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final log = data.logOf(habit.id, today);
    final st = statusOn(habit, log, today, today);
    final amount = log?.amount ?? 0;
    final pct = habit.goalAmount == 0 ? 0.0 : (amount / habit.goalAmount).clamp(0.0, 1.0).toDouble();
    final streak = currentStreak(habit, data.log[habit.id] ?? const {}, today);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            st == DayStatus.done ? Ionicons.checkmark_circle : Ionicons.checkmark_circle_outline,
            size: 22,
            color: st == DayStatus.done ? AppColors.success500 : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(habit.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.label(size: 14, weight: FontWeight.w500)),
                    ),
                    if (streak > 0) Text('🔥$streak', style: AppTypography.label(size: 12, color: AppColors.amber400)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 4,
                    backgroundColor: AppColors.borderDefault,
                    color: st == DayStatus.done ? AppColors.success500 : habitColor(habit),
                  ),
                ),
                const SizedBox(height: 2),
                Text(progressLabel(habit, amount), style: AppTypography.label(size: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
