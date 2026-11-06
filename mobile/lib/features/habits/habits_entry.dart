import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../constants/app_colors.dart';
import '../../core/services/routes.dart';
import '../billing/billing_providers.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/pressable_opacity.dart';
import '../features/feature_models.dart';
import '../features/features_provider.dart';
import 'habits_screen.dart';

/// Habit tracker is a premium feature with a free trial. This decides what the
/// user sees: the trial offer, the tracker (with a "days left" notice), or the
/// "trial ended" page. The server enforces it too — this is the friendly side.
class HabitsEntry extends ConsumerStatefulWidget {
  const HabitsEntry({super.key});

  @override
  ConsumerState<HabitsEntry> createState() => _HabitsEntryState();
}

class _HabitsEntryState extends ConsumerState<HabitsEntry> {
  bool _starting = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    // Fresh answer from the server whenever the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(featuresProvider.notifier).refresh();
      if (mounted) setState(() => _checked = true);
    });
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final ok = await ref.read(featuresProvider.notifier).startTrial('habits');
    if (!mounted) return;
    setState(() => _starting = false);
    if (!ok) {
      AppToast.error('Could not start the trial. Check your connection and try again.');
    } else {
      AppToast.success('Your free trial has started!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = ref.watch(featuresProvider);
    final access = ref.watch(habitsAccessProvider);

    // Waiting for the very first answer (cached answers show instantly).
    if (!fs.loaded && !_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary500)));
    }

    switch (access.state) {
      case AccessState.trialAvailable:
        return _TrialIntro(starting: _starting, onStart: _start, onBack: () => _back(context));
      case AccessState.expired:
      case AccessState.locked:
      case AccessState.disabled:
        return _Paywall(access: access, onBack: () => _back(context));
      case AccessState.trial:
      case AccessState.full:
      case AccessState.unknown:
        return const HabitsScreen();
    }
  }

  void _back(BuildContext context) => context.canPop() ? context.pop() : context.go(AppRoutes.home);
}

/// "You have 14 days free" — shown once, before the trial starts.
class _TrialIntro extends StatelessWidget {
  const _TrialIntro({required this.starting, required this.onStart, required this.onBack});

  final bool starting;
  final VoidCallback onStart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    Widget bullet(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Ionicons.checkmark_circle, size: 20, color: AppColors.success500),
              const SizedBox(width: 10),
              Expanded(child: Text(t, style: AppTypography.label(size: 14, lineHeight: 20))),
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PressableOpacity(
                pressedOpacity: 0.7,
                semanticLabel: 'Back',
                onTap: onBack,
                child: const SizedBox(width: 56, height: 56, child: Icon(Ionicons.arrow_back)),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                child: Column(
                  children: [
                    const Text('🗓️', style: TextStyle(fontSize: 60)),
                    const SizedBox(height: 14),
                    Text('Reading Habit Tracker', style: AppTypography.title22, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'Try it FREE for 14 days',
                      style: AppTypography.label(size: 18, weight: FontWeight.w700, color: AppColors.primary500),
                    ),
                    const SizedBox(height: 18),
                    bullet('Daily pages goals for one or several books'),
                    bullet('Calendar with ticks, streaks and statistics'),
                    bullet('Reminders with snooze, and an evening nudge to protect your streak'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.alpha(AppColors.amber400, 0x14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.alpha(AppColors.amber400, 0x50)),
                      ),
                      child: Text(
                        'The tracker is part of ReadIn Premium. Your free trial lasts 14 days from today. After that you will need Premium to keep using it — your habits and history stay saved.',
                        style: AppTypography.label(size: 13, color: AppColors.textSecondary, lineHeight: 19),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: PressableOpacity(
                pressedOpacity: 0.85,
                onTap: starting ? null : onStart,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.primary500, borderRadius: BorderRadius.circular(14)),
                  child: starting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                        )
                      : Text(
                          'Start my 14-day free trial',
                          style: AppTypography.label(size: 16, weight: FontWeight.w700, color: AppColors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trial over (or feature unavailable).
class _Paywall extends ConsumerWidget {
  const _Paywall({required this.access, required this.onBack});

  final FeatureAccess access;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final off = access.state == AccessState.disabled;
    // No buying screens in the Google Play version (or when the admin switched payments off).
    final canBuy = ref.watch(billingVisibleProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PressableOpacity(
                pressedOpacity: 0.7,
                semanticLabel: 'Back',
                onTap: onBack,
                child: const SizedBox(width: 56, height: 56, child: Icon(Ionicons.arrow_back)),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(off ? '🛠️' : '🔒', style: const TextStyle(fontSize: 56)),
                      const SizedBox(height: 14),
                      Text(
                        off ? 'Habit tracker is unavailable' : 'Your free trial has ended',
                        style: AppTypography.title22,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        off
                            ? 'This feature is switched off for now. Please check back later.'
                            : canBuy
                                ? 'The Reading Habit Tracker is part of ReadIn Premium. Your habits, streaks and history are safely saved and come back the moment you upgrade.'
                                : 'The Reading Habit Tracker is part of ReadIn Premium. Your habits, streaks and history are safely saved and come back when Premium is active on your account.',
                        textAlign: TextAlign.center,
                        style: AppTypography.label(size: 14, color: AppColors.textSecondary, lineHeight: 21),
                      ),
                      if (!off && canBuy) ...[
                        const SizedBox(height: 24),
                        PressableOpacity(
                          pressedOpacity: 0.85,
                          onTap: () => context.push(AppRoutes.upgrade),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: AppColors.primary500, borderRadius: BorderRadius.circular(14)),
                            child: Text(
                              'See ReadIn Premium',
                              style: AppTypography.label(size: 16, weight: FontWeight.w700, color: AppColors.white),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "12 days left of your free trial" strip shown on top of the tracker.
class TrialBanner extends ConsumerWidget {
  const TrialBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(habitsAccessProvider);
    final days = a.daysLeft();
    if (a.state != AccessState.trial || days == null) return const SizedBox.shrink();
    final urgent = days <= 3;
    final color = urgent ? AppColors.error400 : AppColors.amber400;
    final canBuy = ref.watch(billingVisibleProvider);
    return PressableOpacity(
      pressedOpacity: 0.85,
      onTap: canBuy ? () => context.push(AppRoutes.upgrade) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.alpha(color, 0x18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.alpha(color, 0x60)),
        ),
        child: Row(
          children: [
            Icon(urgent ? Ionicons.warning_outline : Ionicons.time_outline, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                days == 1
                    ? (canBuy
                        ? 'Last day of your free trial! Get Premium to keep your habits going.'
                        : 'Last day of your free trial. After today the tracker is part of Premium.')
                    : '$days days left of your free trial. After that the tracker is part of Premium.',
                style: AppTypography.label(size: 13, color: AppColors.textPrimary, lineHeight: 18),
              ),
            ),
            if (canBuy) Icon(Ionicons.chevron_forward, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
