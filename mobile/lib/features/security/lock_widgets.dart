import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/pressable_opacity.dart';
import '../auth/providers/auth_providers.dart';
import '../profile/widgets/settings_row.dart';
import 'app_lock.dart';

/// Covers the whole app (also an open book) until the fingerprint / face is accepted.
class AppLockGate extends ConsumerWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockProvider);
    final signedIn = ref.watch(authProvider.select((a) => a.isAuthenticated));
    final show = lock.enabled && !lock.unlocked && signedIn;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (show) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  @override
  void initState() {
    super.initState();
    // Ask right away — the person only has to touch the sensor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(appLockProvider.notifier).unlock();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appLockProvider);
    return Material(
      key: const ValueKey('lock-screen'),
      color: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Icon(Ionicons.finger_print, size: 64, color: AppColors.primary500)),
              const SizedBox(height: 18),
              Text('ReadIn is locked', textAlign: TextAlign.center, style: AppTypography.title22),
              const SizedBox(height: 8),
              Text(
                'Use your fingerprint or face to continue.',
                textAlign: TextAlign.center,
                style: AppTypography.label(size: 14, color: AppColors.textSecondary),
              ),
              if (s.message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(s.message, textAlign: TextAlign.center, style: AppTypography.label(size: 13, color: AppColors.error500)),
              ],
              const SizedBox(height: 26),
              PressableOpacity(
                pressedOpacity: 0.85,
                onTap: s.busy ? null : () => ref.read(appLockProvider.notifier).unlock(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s.busy ? AppColors.alpha(AppColors.primary500, 0x70) : AppColors.primary500,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Unlock', style: AppTypography.label(size: 16, weight: FontWeight.w700, color: AppColors.white)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: s.busy ? null : () => ref.read(appLockProvider.notifier).usePassword(),
                child: const Text('Use password instead'),
              ),
              Text(
                'This signs you out; sign in again with your e-mail and password. Your books stay on this phone.',
                textAlign: TextAlign.center,
                style: AppTypography.label(size: 11, color: AppColors.textMuted, lineHeight: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profile → App settings: "Unlock with fingerprint / face" (only on phones that have it set up).
class BiometricLockRow extends ConsumerStatefulWidget {
  const BiometricLockRow({super.key});

  @override
  ConsumerState<BiometricLockRow> createState() => _BiometricLockRowState();
}

class _BiometricLockRowState extends ConsumerState<BiometricLockRow> {
  bool _busy = false;

  Future<void> _set(bool on) async {
    if (_busy) return;
    setState(() => _busy = true);
    final n = ref.read(appLockProvider.notifier);
    if (on) {
      final msg = await n.enable();
      if (ref.read(appLockProvider).enabled) {
        AppToast.success(msg);
      } else {
        AppToast.error(msg);
      }
    } else {
      await n.disable();
      AppToast.success('Fingerprint / face unlock is off.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(biometricAvailableProvider).valueOrNull ?? false;
    final enabled = ref.watch(appLockProvider.select((s) => s.enabled));
    if (!available && !enabled) return const SizedBox.shrink();
    return SettingsRow(
      key: const ValueKey('biometric-row'),
      icon: Ionicons.finger_print,
      iconColor: AppColors.success500,
      label: 'Unlock with fingerprint / face',
      sublabel: 'Asks when ReadIn opens and after 5 minutes away',
      rightContent: AppSwitch(value: enabled, onChanged: _busy ? (_) {} : _set),
    );
  }
}
