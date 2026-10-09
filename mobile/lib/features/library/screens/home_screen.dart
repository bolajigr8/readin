import '../../shelves/widgets/shelf_widgets.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../core/services/routes.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/formatters.dart';
import '../../../utils/insets.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_spinner.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../auth/providers/auth_providers.dart';
import '../../goals/widgets/reading_goal_card.dart';
import '../data/models/book.dart';
import '../providers/library_providers.dart';
import '../utils/open_book.dart';
import '../widgets/book_card.dart';
import '../widgets/continue_reading_banner.dart';

/// Opens the reader for [book] (book object passed via `extra`).
void openBook(BuildContext context, Book book) =>
    openBookWith(GoRouter.of(context), book);

/// UI_SPEC §4.5 — Home tab.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final lib = ref.watch(libraryProvider);
    final continueReading = ref.watch(continueReadingProvider);

    final books = lib.valueOrNull?.books ?? const <Book>[];
    final recent = books.where((b) => b.status == 'ready').take(6).toList();
    final hasBooks = recent.isNotEmpty;
    final isLoading = lib.isLoading && !lib.hasValue;
    final hasError = lib.hasError && !lib.hasValue;
    final total = lib.valueOrNull?.meta.total ?? 0;

    final firstName =
        user == null ? 'Reader' : user.displayName.split(' ').first;
    final fabBottom = math.max(deviceBottomInset(context), 16.0) + 16;

    return Stack(
      children: [
        Column(
          children: [
            const AppHeader(
              title: 'Home',
              rightContent: Icon(
                Ionicons.notifications_outline,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 20, bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Greeting
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: '${getGreeting()}, ',
                              style: AppTypography.label(
                                size: 22,
                                weight: FontWeight.w600,
                              ),
                              children: [
                                TextSpan(
                                  text: '$firstName 👋',
                                  style: AppTypography.label(
                                    size: 22,
                                    weight: FontWeight.w700,
                                    color: AppColors.primary500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasBooks
                                ? 'You have $total books in your library'
                                : 'Start reading or add books to your library',
                            style: AppTypography.label(
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Action button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ImportActionCard(
                        onTap: () => context.push(AppRoutes.importBook),
                      ),
                    ),

                    // Daily goal + streak
                    const SizedBox(height: 20),
                    const ReadingGoalCard(),
                    const SizedBox(height: 12),
                    const ChallengeCard(),

                    // Continue reading
                    if (continueReading.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Continue Reading',
                          style: AppTypography.section17,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ContinueReadingBanner(
                        book: continueReading.first,
                        onTap: () => openBook(context, continueReading.first),
                      ),
                    ],

                    // Recent books
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recent Books', style: AppTypography.section17),
                          if (hasBooks)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => context.go(AppRoutes.libraryTab),
                              child: Text(
                                'See all →',
                                style: AppTypography.label(
                                  size: 13,
                                  weight: FontWeight.w500,
                                  color: AppColors.primary500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (isLoading)
                      const SizedBox(height: 180, child: LoadingSpinner())
                    else if (hasError)
                      EmptyState(
                        icon: Ionicons.wifi_outline,
                        title: 'Connection error',
                        description:
                            'Could not load your library. Check your connection.',
                        actionLabel: 'Try Again',
                        onAction: () => refreshLibrary(ref),
                      )
                    else if (!hasBooks)
                      EmptyState(
                        icon: Ionicons.book_outline,
                        title: 'No books yet',
                        description:
                            "Tap 'Import a Book' to add a file, or discover free classics.",
                        actionLabel: 'Import a Book',
                        onAction: () => context.push(AppRoutes.importBook),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < recent.length; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              BookCard(
                                book: recent[i],
                                size: BookCardSize.sm,
                                onTap: () => openBook(context, recent[i]),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // FAB
        Positioned(
          right: 20,
          bottom: fabBottom,
          child: PressableOpacity(
            pressedOpacity: 0.85,
            onTap: () => context.push(AppRoutes.importBook),
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary500,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary500.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Ionicons.book_outline,
                size: 24,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImportActionCard extends StatelessWidget {
  const _ImportActionCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableOpacity(
      pressedOpacity: 0.85,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary500,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Ionicons.book_outline,
                size: 24,
                color: AppColors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import a Book',
                    style: AppTypography.label(
                      size: 16,
                      weight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'PDF or EPUB — opens instantly',
                    style: AppTypography.label(
                      size: 12,
                      color: AppColors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            const Icon(
              Ionicons.chevron_forward,
              size: 18,
              color: AppColors.white,
            ),
          ],
        ),
      ),
    );
  }
}
