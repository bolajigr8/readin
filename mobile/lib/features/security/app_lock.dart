import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers/auth_providers.dart';
import '../auth/providers/auth_state.dart';
import 'biometric_service.dart';

const String kBiometricLockKey = '@readin/biometric_lock';

/// After this long in the background the app asks for the fingerprint / face again.
const Duration kRelockAfter = Duration(minutes: 5);

/// Wrong scans in a row before ReadIn signs out (the password is then needed).
const int kMaxFailures = 3;

class AppLockState {
  const AppLockState({this.enabled = false, this.unlocked = false, this.failures = 0, this.busy = false, this.message = ''});

  /// "Unlock with fingerprint / face" is switched on (on this phone).
  final bool enabled;

  /// Unlocked in this session (false at every cold start and after [kRelockAfter] in the background).
  final bool unlocked;
  final int failures;
  final bool busy;

  /// Short note for the lock screen ("Not recognised — 2 tries left").
  final String message;

  AppLockState copyWith({bool? enabled, bool? unlocked, int? failures, bool? busy, String? message}) => AppLockState(
        enabled: enabled ?? this.enabled,
        unlocked: unlocked ?? this.unlocked,
        failures: failures ?? this.failures,
        busy: busy ?? this.busy,
        message: message ?? this.message,
      );
}

/// Fingerprint / face lock (S4). Nothing goes to the server and no password is stored:
/// the lock only hides the app; "Use password instead" signs out.
class AppLockNotifier extends StateNotifier<AppLockState> {
  AppLockNotifier(this._ref, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now,
        super(AppLockState(enabled: _ref.read(storageServiceProvider).readString(kBiometricLockKey) == '1'));

  final Ref _ref;
  final DateTime Function() _now;
  DateTime? _backgroundSince;

  BiometricService get _bio => _ref.read(biometricServiceProvider);

  /// Show the lock screen now?
  bool get mustShowLock => state.enabled && !state.unlocked && _ref.read(authProvider).isAuthenticated;

  /// Profile switch ON: only after a successful scan (proves the person can unlock). Returns a message.
  Future<String> enable() async {
    if (!await _bio.isAvailable()) {
      return 'Set up a fingerprint or face unlock in your phone settings first.';
    }
    final r = await _bio.authenticate('Confirm it is you to turn on fingerprint / face unlock');
    if (r != BioResult.success) return 'Not turned on — the scan did not succeed.';
    await _ref.read(storageServiceProvider).writeString(kBiometricLockKey, '1');
    if (mounted) state = state.copyWith(enabled: true, unlocked: true, failures: 0, message: '');
    return 'Fingerprint / face unlock is on.';
  }

  Future<void> disable() async {
    await _ref.read(storageServiceProvider).writeString(kBiometricLockKey, '0');
    if (mounted) state = const AppLockState();
  }

  /// Lock-screen button (and automatically when the lock screen appears).
  Future<void> unlock() async {
    if (state.busy || state.unlocked) return;
    state = state.copyWith(busy: true, message: '');
    final r = await _bio.authenticate('Unlock ReadIn');
    if (!mounted) return;
    switch (r) {
      case BioResult.success:
        state = state.copyWith(unlocked: true, failures: 0, busy: false, message: '');
      case BioResult.failed:
        final f = state.failures + 1;
        if (f >= kMaxFailures) {
          state = state.copyWith(busy: false, failures: 0);
          await usePassword();
          return;
        }
        final left = kMaxFailures - f;
        state = state.copyWith(failures: f, busy: false, message: 'Not recognised — $left ${left == 1 ? 'try' : 'tries'} left.');
      case BioResult.lockedOut:
        state = state.copyWith(busy: false, message: 'Too many tries. Wait a little, or use your password.');
      case BioResult.unavailable:
        // The fingerprint / face was removed from the phone: don't trap the person — fall back to the password.
        state = state.copyWith(busy: false);
        await usePassword();
    }
  }

  /// Signs out; the sign-in screen asks for the password. The lock stays on for next time.
  Future<void> usePassword() async {
    await _ref.read(authProvider.notifier).logout();
    if (mounted) state = state.copyWith(unlocked: true, failures: 0, busy: false, message: '');
  }

  /// Called by the app on every lifecycle change.
  void onLifecycle(AppLifecycleState s) {
    if (!state.enabled) return;
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      _backgroundSince ??= _now();
    } else if (s == AppLifecycleState.resumed) {
      final since = _backgroundSince;
      _backgroundSince = null;
      if (state.busy) return; // the fingerprint dialog itself pauses the app
      if (since != null && _now().difference(since) >= kRelockAfter) {
        state = state.copyWith(unlocked: false, failures: 0, message: '');
      }
    }
  }

  /// After signing in with the password the person is in — no second check.
  void markUnlocked() {
    if (mounted && !state.unlocked) state = state.copyWith(unlocked: true, failures: 0, message: '');
  }

  /// A sign-in typed by the person (signed out → signed in) unlocks; restoring a saved session at app start
  /// (not hydrated → signed in) does NOT — that is exactly when the lock must ask.
  void onAuthChange(AuthState? prev, AuthState next) {
    final wasSignedOut = prev != null && prev.isHydrated && prev.status != AuthStatus.authenticated;
    if (wasSignedOut && next.status == AuthStatus.authenticated) markUnlocked();
  }
}

final appLockProvider = StateNotifierProvider<AppLockNotifier, AppLockState>((ref) {
  final n = AppLockNotifier(ref);
  ref.listen<AuthState>(authProvider, n.onAuthChange);
  return n;
});

/// The device can do fingerprint / face (for showing the Profile switch).
final biometricAvailableProvider = FutureProvider.autoDispose<bool>((ref) => ref.read(biometricServiceProvider).isAvailable());
