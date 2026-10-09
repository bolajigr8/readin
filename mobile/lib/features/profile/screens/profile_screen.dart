import '../../shelves/widgets/shelf_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../core/services/routes.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/loading_spinner.dart';
import '../../auth/providers/auth_providers.dart';
import '../../goals/reading_goal.dart';
import '../data/reading_stats.dart';
import '../providers/profile_providers.dart';
import '../widgets/settings_row.dart';

/// UI_SPEC §4.13 — Profile tab.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _showDevTools = false;

  Future<void> _signOut() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      destructive: true,
    );
    if (ok) await ref.read(authProvider.notifier).logout();
  }

  Future<void> _resetOnboarding() async {
    await ref.read(storageServiceProvider).setOnboardingComplete(false);
    if (!mounted) return;
    await showAlertDialog(
      context,
      title: 'Done',
      message: 'Restart the app to see onboarding again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(readingStatsProvider);
    final settings = ref.watch(settingsProvider);
    final settingsCtl = ref.read(settingsProvider.notifier);
    final goal = ref.watch(readingGoalProvider);

    final stats = statsAsync.valueOrNull;
    final loading = statsAsync.isLoading && !statsAsync.hasValue;
    final isPremium = user?.plan == 'premium';
    final name = user?.displayName ?? 'Reader';
    final initials = userInitials(user?.displayName ?? 'U');
    final totalBooks = stats?.totalBooks ?? 0;
    final themeLabel =
        settings.defaultTheme[0].toUpperCase() + settings.defaultTheme.substring(1);

    return Column(
      children: [
        const AppHeader(title: 'Profile'),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary500,
            backgroundColor: AppColors.white,
            onRefresh: () async {
              ref.invalidate(readingStatsProvider);
              try {
                await ref.read(readingStatsProvider.future);
              } catch (_) {}
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 16, bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.alpha(AppColors.primary500, 0x25),
                            border: Border.all(
                              color: AppColors.alpha(AppColors.primary500, 0x50),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            initials,
                            style: AppTypography.label(
                              size: 20,
                              weight: FontWeight.w700,
                              color: AppColors.primary500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label(size: 16, weight: FontWeight.w600),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                user?.email ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label(size: 13, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPremium
                                ? AppColors.alpha(AppColors.amber400, 0x20)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isPremium
                                  ? AppColors.alpha(AppColors.amber400, 0x50)
                                  : AppColors.borderDefault,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPremium) ...[
                                const Icon(Ionicons.star, size: 12, color: AppColors.amber400),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                isPremium ? 'Premium' : 'Free Plan',
                                style: AppTypography.label(
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: isPremium ? AppColors.amber400 : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Reading stats
                  _Section(
                    title: 'READING STATS',
                    child: loading
                        ? const SizedBox(height: 80, child: LoadingSpinner())
                        : _StatsGrid(stats: stats ?? ReadingStats.zero),
                  ),
                  const SizedBox(height: 24),

                  // Reading life
                  _Section(
                    title: 'READING LIFE',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ChallengeCard(),
                        const SizedBox(height: 12),
                        SettingsCard(
                          children: [
                            SettingsRow(
                              icon: Ionicons.create_outline,
                              iconColor: AppColors.primary500,
                              label: 'My Notes & Highlights',
                              sublabel: 'Search, copy and export everything you marked',
                              onTap: () => context.push(AppRoutes.notes),
                            ),
                            SettingsRow(
                              icon: Ionicons.star,
                              iconColor: AppColors.amber400,
                              label: 'Badges',
                              sublabel: 'Streaks, books finished and more',
                              onTap: () => context.push(AppRoutes.badges),
                              isLast: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Subscription
                  _Section(
                    title: 'SUBSCRIPTION',
                    child: SettingsCard(
                      children: [
                        if (isPremium)
                          SettingsRow(
                            icon: Ionicons.star,
                            iconColor: AppColors.amber400,
                            label: 'Premium Active',
                            sublabel: 'Unlimited books, annotations, and more',
                            onTap: () => context.push(AppRoutes.upgrade),
                            isLast: true,
                          )
                        else ...[
                          SettingsRow(
                            icon: Ionicons.flash_outline,
                            iconColor: AppColors.primary500,
                            label: 'Upgrade to Premium',
                            sublabel: 'Unlimited books, annotations, audio and more',
                            onTap: () => context.push(AppRoutes.upgrade),
                            isLast: true,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    text: 'Free plan: ',
                                    style: AppTypography.label(
                                      size: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '$totalBooks / 10 books',
                                        style: AppTypography.label(
                                          size: 13,
                                          weight: FontWeight.w600,
                                          color: AppColors.primary500,
                                        ),
                                      ),
                                      const TextSpan(text: ' used'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: Container(
                                    height: 4,
                                    color: AppColors.borderDefault,
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: (totalBooks / 10).clamp(0.0, 1.0),
                                      heightFactor: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: AppColors.primary500,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Reader preferences
                  _Section(
                    title: 'READER PREFERENCES',
                    child: SettingsCard(
                      children: [
                        SettingsRow(
                          icon: Ionicons.text_outline,
                          iconColor: AppColors.primary500,
                          label: 'Default Font Size',
                          sublabel: '${settings.defaultFontSize.round()}px',
                          rightContent: _SizeControl(
                            value: settings.defaultFontSize.round(),
                            onChanged: (v) => settingsCtl.setFontSize(v.toDouble()),
                          ),
                        ),
                        SettingsRow(
                          icon: Ionicons.flash_outline,
                          iconColor: AppColors.success500,
                          label: 'Daily Reading Goal',
                          sublabel: '${goal.goalMinutes} min per day',
                          rightContent: _SizeControl(
                            value: goal.goalMinutes,
                            min: 5,
                            max: 180,
                            step: 5,
                            onChanged: (v) =>
                                ref.read(readingGoalProvider.notifier).setGoal(v),
                          ),
                        ),
                        SettingsRow(
                          icon: Ionicons.color_palette_outline,
                          iconColor: AppColors.amber400,
                          label: 'Default Theme',
                          sublabel: themeLabel,
                          onTap: settingsCtl.cycleTheme,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // App settings
                  _Section(
                    title: 'APP SETTINGS',
                    child: SettingsCard(
                      children: [
                        SettingsRow(
                          icon: Ionicons.notifications_outline,
                          iconColor: AppColors.primary400,
                          label: 'Push Notifications',
                          sublabel: 'Updates about your library',
                          rightContent: AppSwitch(
                            value: settings.notificationsEnabled,
                            onChanged: settingsCtl.setNotifications,
                          ),
                        ),
                        SettingsRow(
                          icon: Ionicons.cloud_download_outline,
                          iconColor: AppColors.success500,
                          label: 'Auto-download EPUBs',
                          sublabel: 'Download when adding to library',
                          isLast: true,
                          rightContent: AppSwitch(
                            value: settings.autoDownloadEpub,
                            onChanged: settingsCtl.setAutoDownload,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account
                  _Section(
                    title: 'ACCOUNT',
                    child: SettingsCard(
                      children: [
                        SettingsRow(
                          icon: Ionicons.mail_outline,
                          iconColor: AppColors.textMuted,
                          label: 'Email',
                          sublabel: user?.email ?? '',
                        ),
                        SettingsRow(
                          icon: Ionicons.log_out_outline,
                          iconColor: AppColors.error500,
                          label: 'Sign Out',
                          onTap: _signOut,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // App info + dev tools
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: kReleaseMode
                        ? null
                        : () => setState(() => _showDevTools = !_showDevTools),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            'ReadIn v1.0.0',
                            style: AppTypography.label(size: 13, color: AppColors.textMuted),
                          ),
                          if (!kReleaseMode) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Long-press to ${_showDevTools ? 'hide' : 'show'} dev tools',
                              style: AppTypography.label(
                                size: 11,
                                color: AppColors.alpha(AppColors.textMuted, 0x80),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_showDevTools) ...[
                    const SizedBox(height: 24),
                    _Section(
                      title: 'DEVELOPER TOOLS',
                      child: SettingsCard(
                        children: [
                          SettingsRow(
                            icon: Ionicons.refresh_outline,
                            iconColor: AppColors.warning500,
                            label: 'Reset Onboarding',
                            sublabel: 'Restart the app to see it',
                            onTap: _resetOnboarding,
                            isLast: !kDebugMode,
                          ),
                          if (kDebugMode)
                            SettingsRow(
                              icon: Ionicons.color_wand_outline,
                              iconColor: AppColors.purple500,
                              label: 'Design gallery',
                              sublabel: 'Debug builds only',
                              onTap: () => context.push(AppRoutes.gallery),
                              isLast: true,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final cells = <(String, String)>[
      ('${stats.totalBooks}', 'Books'),
      ('${stats.completedBooks}', 'Completed'),
      (formatReadingTime(stats.totalReadingTimeSeconds), 'Read Time'),
      ('${stats.annotationCount}', 'Highlights'),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: i == cells.length - 1
                        ? null
                        : const Border(right: BorderSide(color: AppColors.borderDefault)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        cells[i].$1,
                        style: AppTypography.label(
                          size: 22,
                          weight: FontWeight.w700,
                          color: AppColors.primary500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cells[i].$2,
                        style: AppTypography.label(size: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SizeControl extends StatelessWidget {
  const _SizeControl({
    required this.value,
    required this.onChanged,
    this.min = 12,
    this.max = 28,
    this.step = 2,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, bool enabled, int next) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged(next) : null,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.primary500 : AppColors.textMuted,
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Ionicons.remove_circle_outline, value > min, value - step),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppTypography.label(size: 15, weight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        btn(Ionicons.add_circle_outline, value < max, value + step),
      ],
    );
  }
}
