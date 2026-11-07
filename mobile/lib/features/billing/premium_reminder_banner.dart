import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../constants/app_colors.dart';
import '../../core/services/routes.dart';
import '../../theme/app_typography.dart';
import '../../widgets/pressable_opacity.dart';
import '../auth/providers/auth_providers.dart';
import 'billing_models.dart';
import 'billing_providers.dart';

const String _kDismissed = '@readin/premium_banner_dismissed';

/// Kind Home-screen banner when Premium is ending or has ended (days set by the admin, S9.2).
/// "Later" hides it until the next reminder day. Hidden where buying is not possible (Play version for now).
class PremiumReminderBanner extends ConsumerStatefulWidget {
  const PremiumReminderBanner({super.key, this.now});

  /// For tests; null = the real clock.
  final DateTime? now;

  @override
  ConsumerState<PremiumReminderBanner> createState() => _PremiumReminderBannerState();
}

class _PremiumReminderBannerState extends ConsumerState<PremiumReminderBanner> {
  String? _dismissed;

  @override
  void initState() {
    super.initState();
    _dismissed = ref.read(storageServiceProvider).readString(_kDismissed);
  }

  void _later(PremiumReminder r) {
    setState(() => _dismissed = r.dismissKey);
    ref.read(storageServiceProvider).writeString(_kDismissed, r.dismissKey);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(billingVisibleProvider)) return const SizedBox.shrink();
    final user = ref.watch(currentUserProvider);
    final offsets = ref.watch(publicConfigProvider.select((c) => c.billing.reminders));
    final r = premiumReminderFor(user?.premiumUntil, widget.now ?? DateTime.now(), offsets);
    if (r == null || r.dismissKey == _dismissed) return const SizedBox.shrink();

    final ended = r.kind == PremiumReminderKind.after;
    final tone = ended ? AppColors.primary500 : AppColors.amber400;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        key: const ValueKey('premium-reminder-banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.alpha(tone, 0x18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.alpha(tone, 0x70)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ended ? Ionicons.heart_outline : Ionicons.star, size: 20, color: tone),
                const SizedBox(width: 8),
                Expanded(child: Text(r.title, style: AppTypography.label(size: 15, weight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 6),
            Text(r.message, style: AppTypography.label(size: 13, color: AppColors.textSecondary, lineHeight: 19)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => _later(r), child: const Text('Later')),
                const SizedBox(width: 6),
                PressableOpacity(
                  pressedOpacity: 0.85,
                  semanticLabel: 'Renew Premium',
                  onTap: () => context.push(AppRoutes.upgrade),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.primary500, borderRadius: BorderRadius.circular(10)),
                    child: Text('Renew', style: AppTypography.label(size: 14, weight: FontWeight.w700, color: AppColors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
