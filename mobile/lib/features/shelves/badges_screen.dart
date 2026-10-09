import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../constants/app_colors.dart';
import '../../core/services/routes.dart';
import '../../theme/app_typography.dart';
import '../../widgets/pressable_opacity.dart';
import '../auth/providers/auth_providers.dart';
import '../goals/reading_goal.dart';
import '../library/data/models/book.dart';
import '../library/providers/library_providers.dart';
import '../profile/providers/profile_providers.dart';
import 'badges.dart';
import 'shelf_models.dart';
import 'shelf_providers.dart';

/// Numbers behind the badges (library + shelves + goal + server stats).
final badgeStatusProvider = Provider.autoDispose<List<BadgeStatus>>((ref) {
  final books = ref.watch(libraryProvider).valueOrNull?.books ?? const <Book>[];
  final shelves = ref.watch(shelvesProvider);
  final goal = ref.watch(readingGoalProvider);
  final stats = ref.watch(readingStatsProvider).valueOrNull;
  final storage = ref.watch(storageServiceProvider);
  return evaluateBadges(
    BadgeInput(
      finishedBooks: books.where((b) => effectiveStatus(b, shelves) == ReadStatus.finished).length,
      libraryBooks: books.length,
      streak: goal.streak,
      readingSeconds: stats?.totalReadingTimeSeconds ?? 0,
      annotations: stats?.annotationCount ?? 0,
      nightSeconds: storage.readInt('@readin/night_seconds'),
      goalDays: storage.readInt('@readin/goal_days'),
    ),
  );
});

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgeStatusProvider);
    final unlocked = badges.where((b) => b.unlocked).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  PressableOpacity(
                    pressedOpacity: 0.7,
                    semanticLabel: 'Back',
                    onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.profile),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Ionicons.arrow_back, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Badges', style: AppTypography.label(size: 22, weight: FontWeight.w700)),
                        Text(
                          '$unlocked of ${badges.length} unlocked',
                          style: AppTypography.label(size: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: badges.length,
                itemBuilder: (context, i) {
                  final b = badges[i];
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: b.unlocked
                          ? AppColors.alpha(AppColors.primary500, 0x12)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: b.unlocked
                            ? AppColors.alpha(AppColors.primary500, 0x50)
                            : AppColors.borderDefault,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: b.unlocked ? 1 : 0.3,
                          child: Text(b.def.emoji, style: const TextStyle(fontSize: 34)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          b.def.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label(size: 12, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          b.def.description,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label(size: 10, color: AppColors.textMuted, lineHeight: 13),
                        ),
                        const SizedBox(height: 6),
                        if (!b.unlocked)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: b.progress,
                              minHeight: 3,
                              backgroundColor: AppColors.borderDefault,
                              color: AppColors.primary500,
                            ),
                          )
                        else
                          Text(
                            'Unlocked',
                            style: AppTypography.label(
                              size: 10,
                              weight: FontWeight.w600,
                              color: AppColors.primary500,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
