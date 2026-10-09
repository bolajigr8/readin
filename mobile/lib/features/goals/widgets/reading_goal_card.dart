import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../reading_goal.dart';

/// Home card: daily goal ring, streak and the last 7 days.
class ReadingGoalCard extends ConsumerStatefulWidget {
  const ReadingGoalCard({super.key});

  @override
  ConsumerState<ReadingGoalCard> createState() => _ReadingGoalCardState();
}

class _ReadingGoalCardState extends ConsumerState<ReadingGoalCard> {
  @override
  void initState() {
    super.initState();
    // New day since the app was opened? Re-read the counters.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(readingGoalProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(readingGoalProvider);
    final maxSeconds = math.max(g.goalMinutes * 60, g.last7.fold<int>(0, math.max));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CustomPaint(
              painter: _RingPainter(
                progress: g.progress,
                color: g.goalReached ? AppColors.success500 : AppColors.primary500,
              ),
              child: Center(
                child: g.goalReached
                    ? const Icon(Icons.check_rounded, size: 26, color: AppColors.success500)
                    : Text(
                        '${g.todayMinutes}',
                        style: AppTypography.label(size: 18, weight: FontWeight.w700),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.goalReached ? 'Goal reached! 🎉' : "Today's reading",
                  style: AppTypography.label(size: 15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${g.todayMinutes} of ${g.goalMinutes} min',
                  style: AppTypography.label(size: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.alpha(AppColors.amber400, g.streak > 0 ? 0x20 : 0x10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    g.streak > 0
                        ? '🔥 ${g.streak} day${g.streak == 1 ? '' : 's'} streak'
                        : 'Read today to start a streak',
                    style: AppTypography.label(
                      size: 11,
                      weight: FontWeight.w600,
                      color: g.streak > 0 ? AppColors.amber400 : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 7-day bars
          SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < g.last7.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 8,
                        height: maxSeconds <= 0
                            ? 3
                            : math.max(3.0, 36 * g.last7[i] / maxSeconds),
                        decoration: BoxDecoration(
                          color: i == g.last7.length - 1
                              ? AppColors.primary500
                              : AppColors.alpha(AppColors.primary500, 0x60),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        g.weekdays[i],
                        style: AppTypography.label(size: 9, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.borderDefault;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = color;
    canvas.drawArc(arc, 0, math.pi * 2, false, track);
    if (progress > 0) {
      canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * progress, false, fill);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}
