// S4 — fingerprint / face lock: when it asks, failures, sign-out fallback, gate.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readin_flutter/core/services/storage_service.dart';
import 'package:readin_flutter/features/auth/data/models/auth_user.dart';
import 'package:readin_flutter/features/auth/providers/auth_providers.dart';
import 'package:readin_flutter/features/auth/providers/auth_state.dart';
import 'package:readin_flutter/features/security/app_lock.dart';
import 'package:readin_flutter/features/security/biometric_service.dart';
import 'package:readin_flutter/features/security/lock_widgets.dart';

const _user = AuthUser(id: 'u1', email: 'r@readin.test', displayName: 'Reader', avatar: '', plan: 'free', isEmailVerified: true);

class _FakeBio implements BiometricService {
  bool available = true;
  final List<BioResult> answers = [];
  int asked = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BioResult> authenticate(String reason) async {
    asked++;
    return answers.isEmpty ? BioResult.success : answers.removeAt(0);
  }
}

/// Signed in from the start (like a restored session); logout() just flips the state (no network).
class _Auth extends AuthNotifier {
  _Auth(super.ref, {bool signedIn = true}) {
    state = signedIn
        ? const AuthState(status: AuthStatus.authenticated, isHydrated: true, user: _user)
        : const AuthState(status: AuthStatus.loggedOut, isHydrated: true);
  }
  int logouts = 0;

  @override
  Future<void> hydrate() async {}

  @override
  Future<void> logout() async {
    logouts++;
    state = const AuthState(status: AuthStatus.loggedOut, isHydrated: true);
  }

  void signInByHand() => state = const AuthState(status: AuthStatus.authenticated, isHydrated: true, user: _user);
}

void main() {
  late _FakeBio bio;
  late DateTime now;

  Future<ProviderContainer> make({bool lockOn = true, bool signedIn = true}) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(prefs: await SharedPreferences.getInstance());
    if (lockOn) await storage.writeString(kBiometricLockKey, '1');
    final c = ProviderContainer(overrides: [
      storageServiceProvider.overrideWithValue(storage),
      biometricServiceProvider.overrideWithValue(bio),
      authProvider.overrideWith((ref) => _Auth(ref, signedIn: signedIn)),
      appLockProvider.overrideWith((ref) {
        final n = AppLockNotifier(ref, clock: () => now);
        ref.listen<AuthState>(authProvider, n.onAuthChange);
        return n;
      }),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    bio = _FakeBio();
    now = DateTime(2026, 11, 7, 10);
  });

  test('switched off → never asks', () async {
    final c = await make(lockOn: false);
    expect(c.read(appLockProvider.notifier).mustShowLock, isFalse);
  });

  test('switched on → locked at app start (restored session), unlocks with the finger', () async {
    final c = await make();
    final n = c.read(appLockProvider.notifier);
    expect(n.mustShowLock, isTrue);
    await n.unlock();
    expect(n.mustShowLock, isFalse);
    expect(bio.asked, 1);
  });

  test('signed out → no lock screen (the sign-in screen is enough)', () async {
    final c = await make(signedIn: false);
    expect(c.read(appLockProvider.notifier).mustShowLock, isFalse);
  });

  test('signing in with the password unlocks — no second check', () async {
    final c = await make(signedIn: false);
    c.read(appLockProvider); // create (starts listening)
    (c.read(authProvider.notifier) as _Auth).signInByHand();
    expect(c.read(appLockProvider.notifier).mustShowLock, isFalse);
  });

  test('locks again after 5 minutes in the background, not after 4', () async {
    final c = await make();
    final n = c.read(appLockProvider.notifier);
    await n.unlock();
    n.onLifecycle(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 4));
    n.onLifecycle(AppLifecycleState.resumed);
    expect(n.mustShowLock, isFalse);
    n.onLifecycle(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 5));
    n.onLifecycle(AppLifecycleState.resumed);
    expect(n.mustShowLock, isTrue);
  });

  test('wrong finger: "2 tries left", then "1 try left", third time signs out', () async {
    final c = await make();
    final n = c.read(appLockProvider.notifier);
    bio.answers.addAll([BioResult.failed, BioResult.failed, BioResult.failed]);
    await n.unlock();
    expect(c.read(appLockProvider).message, contains('2 tries left'));
    await n.unlock();
    expect(c.read(appLockProvider).message, contains('1 try left'));
    await n.unlock();
    expect((c.read(authProvider.notifier) as _Auth).logouts, 1);
    expect(n.mustShowLock, isFalse);
    expect(c.read(appLockProvider).enabled, isTrue, reason: 'the lock stays on for next time');
  });

  test('fingerprint removed from the phone → falls back to the password (never trapped)', () async {
    final c = await make();
    bio.answers.add(BioResult.unavailable);
    await c.read(appLockProvider.notifier).unlock();
    expect((c.read(authProvider.notifier) as _Auth).logouts, 1);
  });

  test('turning ON needs a successful scan and a set-up sensor', () async {
    final c = await make(lockOn: false);
    final n = c.read(appLockProvider.notifier);
    bio.available = false;
    expect(await n.enable(), contains('phone settings'));
    expect(c.read(appLockProvider).enabled, isFalse);
    bio.available = true;
    bio.answers.add(BioResult.failed);
    await n.enable();
    expect(c.read(appLockProvider).enabled, isFalse);
    await n.enable();
    expect(c.read(appLockProvider).enabled, isTrue);
    expect(c.read(storageServiceProvider).readString(kBiometricLockKey), '1');
    await n.disable();
    expect(c.read(storageServiceProvider).readString(kBiometricLockKey), '0');
  });

  testWidgets('the gate covers the app until unlocked', (tester) async {
    bio.answers.add(BioResult.failed); // the automatic first ask fails
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(prefs: await SharedPreferences.getInstance());
    await storage.writeString(kBiometricLockKey, '1');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        biometricServiceProvider.overrideWithValue(bio),
        authProvider.overrideWith((ref) => _Auth(ref)),
      ],
      child: const MaterialApp(home: AppLockGate(child: Scaffold(body: Text('my books')))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
    expect(find.textContaining('2 tries left'), findsOneWidget);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lock-screen')), findsNothing);
    expect(find.text('my books'), findsOneWidget);
  });
}
