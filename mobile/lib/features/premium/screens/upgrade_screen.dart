import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../core/services/routes.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/premium_service.dart';
import '../providers/premium_providers.dart';

/// UI_SPEC §4.16 — Upgrade (modal).
class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  String _selected = 'premium_annual';
  bool _purchasing = false;
  bool _restoring = false;

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.profile);
    }
  }

  Future<void> _activated() async {
    // TODO(server): there is no GET /auth/me; the server flips `plan` through
    // the RevenueCat webhook. Until a refresh endpoint exists, reflect the
    // entitlement locally so the UI unlocks immediately.
    final user = ref.read(currentUserProvider);
    if (user != null) await ref.read(authProvider.notifier).setUser(user.copyWith(plan: 'premium'));
    if (!mounted) return;
    AppToast.success('Premium activated!');
    _close();
  }

  Future<void> _comingSoon() => showAlertDialog(
        context,
        title: 'Premium is coming soon ✨',
        message:
            'Unlimited books, cloud backup, advanced stats and more are on the way. Everything you use today stays free.',
      );

  Future<void> _purchase() async {
    if (kPremiumComingSoon) {
      await _comingSoon();
      return;
    }
    if (_purchasing) return;
    setState(() => _purchasing = true);
    PremiumResult result;
    try {
      result = await ref.read(premiumServiceProvider).purchase(_selected);
    } catch (_) {
      result = PremiumResult.failed;
    }
    if (!mounted) return;
    setState(() => _purchasing = false);

    switch (result) {
      case PremiumResult.success:
        await _activated();
      case PremiumResult.cancelled:
        break; // not an error
      case PremiumResult.unavailable:
        AppToast.info('Purchase flow available in production build.');
      case PremiumResult.nothingToRestore:
      case PremiumResult.failed:
        AppToast.error('Purchase failed. Please try again.');
    }
  }

  Future<void> _restore() async {
    if (kPremiumComingSoon) {
      await _comingSoon();
      return;
    }
    if (_restoring) return;
    setState(() => _restoring = true);
    PremiumResult result;
    try {
      result = await ref.read(premiumServiceProvider).restore();
    } catch (_) {
      result = PremiumResult.failed;
    }
    if (!mounted) return;
    setState(() => _restoring = false);

    switch (result) {
      case PremiumResult.success:
        AppToast.success('Premium restored!');
        await _activated();
      case PremiumResult.nothingToRestore:
        AppToast.info('No active subscription found.');
      case PremiumResult.unavailable:
        AppToast.info('Restore available in production build.');
      case PremiumResult.cancelled:
        break;
      case PremiumResult.failed:
        AppToast.error('Could not restore purchases.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hero(),
                  const SizedBox(height: 28),
                  _featuresCard(),
                  const SizedBox(height: 28),
                  _packages(),
                  const SizedBox(height: 28),
                  _subscribeButton(),
                  const SizedBox(height: 28 - 12),
                  _restoreButton(),
                  const SizedBox(height: 28),
                  Text(
                    'Subscription auto-renews. Cancel any time in your App Store or Google Play account settings. By subscribing you agree to our Terms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: AppTypography.label(
                      size: 11,
                      color: AppColors.textMuted,
                      lineHeight: 17,
                    ),
                  ),
                ],
              ),
            ),
            // RN: absolute top 54 / right 20 (from the screen edge).
            Positioned(
              top: (54 - MediaQuery.viewPaddingOf(context).top).clamp(0.0, 200.0).toDouble(),
              right: 20,
              child: PressableOpacity(
                pressedOpacity: 0.7,
                semanticLabel: 'Close',
                onTap: _close,
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Ionicons.close, size: 22, color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.alpha(AppColors.amber400, 0x20),
                border: Border.all(
                  color: AppColors.alpha(AppColors.amber400, 0x40),
                  width: 2,
                ),
              ),
              child: const Icon(Ionicons.star, size: 36, color: AppColors.amber400),
            ),
            const SizedBox(height: 12),
            Text(
              'ReadIn Premium',
              style: AppTypography.label(size: 28, weight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Unlock the full reading experience with unlimited books, highlights, and audio.',
              textAlign: TextAlign.center,
              style: AppTypography.label(
                size: 15,
                color: AppColors.textSecondary,
                lineHeight: 22,
              ),
            ),
          ],
        ),
      );

  Widget _featuresCard() {
    final headStyle = AppTypography.label(
      size: 13,
      weight: FontWeight.w600,
      color: AppColors.textSecondary,
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          Container(
            color: AppColors.elevated,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Expanded(child: SizedBox.shrink()),
                SizedBox(
                  width: 80,
                  child: Text('Free', textAlign: TextAlign.center, style: headStyle),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'Premium',
                    textAlign: TextAlign.center,
                    style: headStyle.copyWith(color: AppColors.amber400),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.borderDefault),
          for (var i = 0; i < kPremiumFeatures.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: i == kPremiumFeatures.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: AppColors.alpha(AppColors.borderDefault, 0x60),
                        ),
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(kPremiumFeatures[i].label, style: AppTypography.body14),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      kPremiumFeatures[i].free,
                      textAlign: TextAlign.center,
                      style: AppTypography.label(size: 12, color: AppColors.textMuted),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      kPremiumFeatures[i].premium,
                      textAlign: TextAlign.center,
                      style: AppTypography.label(size: 12, color: AppColors.success400),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _packages() {
    return Column(
      children: [
        for (var i = 0; i < kPremiumPackages.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _PackageCard(
            package: kPremiumPackages[i],
            selected: _selected == kPremiumPackages[i].id,
            onTap: () => setState(() => _selected = kPremiumPackages[i].id),
          ),
        ],
      ],
    );
  }

  Widget _subscribeButton() {
    return PressableOpacity(
      pressedOpacity: 0.85,
      onTap: _purchasing ? null : _purchase,
      child: Opacity(
        opacity: _purchasing ? 0.7 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.amber400,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Ionicons.star, size: 18, color: AppColors.black),
              const SizedBox(width: 8),
              Text(
                _purchasing ? 'Processing...' : 'Start Premium',
                style: AppTypography.label(
                  size: 17,
                  weight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _restoreButton() {
    return PressableOpacity(
      pressedOpacity: 0.7,
      onTap: _restoring ? null : _restore,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            _restoring ? 'Restoring...' : 'Restore Purchases',
            style: AppTypography.label(
              size: 14,
              color: AppColors.textMuted,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  final PremiumPackage package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableOpacity(
      pressedOpacity: 0.8,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.alpha(AppColors.amber400, 0x08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.amber400 : AppColors.borderDefault,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? AppColors.amber400 : AppColors.borderLight,
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.amber400,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            package.title,
                            style: AppTypography.label(size: 15, weight: FontWeight.w600),
                          ),
                          Text(
                            package.period,
                            style: AppTypography.label(size: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  package.price,
                  style: AppTypography.label(
                    size: 20,
                    weight: FontWeight.w700,
                    color: selected ? AppColors.amber400 : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (package.savings != null)
            Positioned(
              top: -10,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.amber400,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  package.savings!,
                  style: AppTypography.label(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
