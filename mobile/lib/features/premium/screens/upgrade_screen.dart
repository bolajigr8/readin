import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../core/services/routes.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../auth/providers/auth_providers.dart';
import '../../billing/billing_models.dart';
import '../../billing/billing_providers.dart';
import '../../billing/checkout_screen.dart';
import '../../features/features_provider.dart';

/// Premium: pick a plan (prices in naira, set by the admin) and pay with Paystack.
class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  String? _selectedId;
  bool _busy = false;
  String _busyLabel = '';

  @override
  void initState() {
    super.initState();
    // fresh plans / prices every time the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(publicConfigProvider.notifier).refresh());
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.profile);
    }
  }

  PublicPlan? _plan(List<PublicPlan> plans) {
    if (plans.isEmpty) return null;
    return plans.firstWhere((p) => p.id == _selectedId, orElse: () => plans.first);
  }

  Future<void> _pay(PublicPlan plan) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyLabel = 'Starting payment…';
    });
    final res = await ref.read(billingApiProvider).checkout(plan.id);
    if (!mounted) return;
    final session = res.dataOrNull;
    if (session == null) {
      setState(() => _busy = false);
      AppToast.error(res.exceptionOrNull?.message ?? 'Could not start the payment.');
      return;
    }
    setState(() => _busy = false);

    final reference = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => PaystackCheckoutScreen(
          url: session.authorizationUrl,
          reference: session.reference,
          title: 'Pay ${session.amountText}',
        ),
      ),
    );
    if (!mounted) return;
    await _confirm(reference ?? session.reference);
  }

  /// Asks the server whether the payment went through (Paystack can need a few seconds).
  Future<void> _confirm(String reference) async {
    setState(() {
      _busy = true;
      _busyLabel = 'Confirming your payment…';
    });
    PaymentVerification? result;
    for (var attempt = 0; attempt < 5; attempt++) {
      final r = await ref.read(billingApiProvider).verify(reference);
      result = r.dataOrNull;
      if (result != null && result.status != PaymentStatus.pending) break;
      if (!mounted) return;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result?.status) {
      case PaymentStatus.success:
        await ref.read(refreshUserProvider)();
        await ref.read(featuresProvider.notifier).refresh();
        if (!mounted) return;
        await showAlertDialog(
          context,
          title: 'Premium is active! 🎉',
          message: result?.premiumUntil == null
              ? 'Thank you! Your Premium features are unlocked.'
              : 'Thank you! Premium is active until ${DateFormat.yMMMMd().format(result!.premiumUntil!.toLocal())}. A receipt was sent to your e-mail.',
        );
        if (mounted) _close();
      case PaymentStatus.failed:
        AppToast.error('The payment was not completed. You have not been charged.');
      case PaymentStatus.pending:
      case null:
        if (!mounted) return;
        await showAlertDialog(
          context,
          title: 'Still processing',
          message:
              'We have not received the confirmation from your bank yet. If you were charged, Premium will switch on by itself within a few minutes — you do not need to pay again.',
        );
        await ref.read(refreshUserProvider)();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(publicConfigProvider);
    final user = ref.watch(currentUserProvider);
    final billing = cfg.billing;
    final plan = _plan(billing.plans);
    final isPremium = user?.plan == 'premium';
    final canBuy = ref.watch(billingVisibleProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: PressableOpacity(
                pressedOpacity: 0.7,
                semanticLabel: 'Close',
                onTap: _close,
                child: const SizedBox(width: 52, height: 52, child: Icon(Ionicons.close, color: AppColors.textPrimary)),
              ),
            ),
            Expanded(
              child: !canBuy && !isPremium
                  ? _Unavailable(onClose: _close)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: Text('✨', style: TextStyle(fontSize: 54))),
                          const SizedBox(height: 10),
                          Text('ReadIn Premium', textAlign: TextAlign.center, style: AppTypography.title22),
                          const SizedBox(height: 6),
                          Text(
                            'Read without limits and unlock every feature.',
                            textAlign: TextAlign.center,
                            style: AppTypography.label(size: 14, color: AppColors.textSecondary),
                          ),
                          if (isPremium) ...[
                            const SizedBox(height: 18),
                            _ActiveBanner(until: user?.premiumUntil),
                          ],
                          const SizedBox(height: 22),
                          _Benefits(freeLimit: billing.freeLibraryLimit),
                          const SizedBox(height: 24),
                          if (canBuy) ...[
                            Text(
                              isPremium ? 'ADD MORE TIME' : 'CHOOSE A PLAN',
                              style: AppTypography.label(size: 11, weight: FontWeight.w600, letterSpacing: 0.8, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 10),
                            if (billing.plans.isEmpty)
                              Text('No plans are available right now.', style: AppTypography.label(size: 14, color: AppColors.textSecondary))
                            else
                              for (final p in billing.plans)
                                _PlanCard(
                                  plan: p,
                                  selected: (plan?.id ?? '') == p.id,
                                  onTap: () => setState(() => _selectedId = p.id),
                                ),
                            const SizedBox(height: 16),
                            PressableOpacity(
                              pressedOpacity: 0.85,
                              onTap: (_busy || plan == null) ? null : () => _pay(plan),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: (_busy || plan == null) ? AppColors.alpha(AppColors.primary500, 0x70) : AppColors.primary500,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: _busy
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(_busyLabel, style: AppTypography.label(size: 15, weight: FontWeight.w600, color: AppColors.white)),
                                        ],
                                      )
                                    : Text(
                                        plan == null ? 'Pay with Paystack' : 'Pay ${plan.priceText} with Paystack',
                                        style: AppTypography.label(size: 16, weight: FontWeight.w700, color: AppColors.white),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Ionicons.lock_closed_outline, size: 14, color: AppColors.success500),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Secure payment by Paystack — card, bank transfer or USSD',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.label(size: 12, color: AppColors.textMuted),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'One payment per period — it does not renew by itself, so you are never charged again unless you choose to pay.',
                              textAlign: TextAlign.center,
                              style: AppTypography.label(size: 11, color: AppColors.textMuted, lineHeight: 16),
                            ),
                          ],
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

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💳', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('Payments are not available', style: AppTypography.title20, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'There is nothing to buy right now. Everything you use today stays available.',
                textAlign: TextAlign.center,
                style: AppTypography.label(size: 14, color: AppColors.textSecondary, lineHeight: 21),
              ),
              const SizedBox(height: 18),
              TextButton(onPressed: onClose, child: const Text('Go back')),
            ],
          ),
        ),
      );
}

class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({required this.until});
  final DateTime? until;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.alpha(AppColors.success500, 0x18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.alpha(AppColors.success500, 0x60)),
        ),
        child: Row(
          children: [
            const Icon(Ionicons.checkmark_circle, color: AppColors.success500),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                until == null
                    ? 'Premium is active on your account.'
                    : 'Premium is active until ${DateFormat.yMMMMd().format(until!.toLocal())}.',
                style: AppTypography.label(size: 14, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _Benefits extends StatelessWidget {
  const _Benefits({required this.freeLimit});
  final int freeLimit;

  @override
  Widget build(BuildContext context) {
    Widget row(String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Ionicons.checkmark_circle, size: 20, color: AppColors.primary500),
              const SizedBox(width: 12),
              Expanded(child: Text(t, style: AppTypography.label(size: 14, lineHeight: 20))),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          row('Unlimited books (Free plan: up to $freeLimit)'),
          row('Reading Habit Tracker with reminders and streaks'),
          row('Every new Premium feature we add'),
          row('Supports the ReadIn app'),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.selected, required this.onTap});

  final PublicPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressableOpacity(
        pressedOpacity: 0.85,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppColors.alpha(AppColors.primary500, 0x14) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.primary500 : AppColors.borderDefault, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(selected ? Ionicons.checkmark_circle : Ionicons.radio_button_off, color: selected ? AppColors.primary500 : AppColors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(plan.name, style: AppTypography.label(size: 16, weight: FontWeight.w700))),
                        if (plan.badge.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.amber400, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              plan.badge,
                              style: AppTypography.label(size: 10, weight: FontWeight.w700, color: AppColors.black),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.description.isEmpty ? durationText(plan.durationDays) : plan.description,
                      style: AppTypography.label(size: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(plan.priceText, style: AppTypography.label(size: 18, weight: FontWeight.w800, color: AppColors.primary500)),
                  Text(durationText(plan.durationDays), style: AppTypography.label(size: 11, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
