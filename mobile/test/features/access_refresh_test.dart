// S0.6 — an admin change (feature switched off, payments switched off) must
// reach a running app within about a minute.
//  * AccessRefreshScheduler: the timing rules used by lib/app/app.dart.
//  * featuresProvider / publicConfigProvider: a refresh picks up the new answer.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readin_flutter/app/access_refresh.dart';
import 'package:readin_flutter/core/services/storage_service.dart';
import 'package:readin_flutter/features/auth/data/models/auth_user.dart';
import 'package:readin_flutter/features/auth/providers/auth_providers.dart';
import 'package:readin_flutter/features/auth/providers/auth_state.dart';
import 'package:readin_flutter/features/billing/billing_providers.dart';
import 'package:readin_flutter/features/features/features_provider.dart';

import '../helpers/test_rig.dart';

TestReply _ok(Object data) => (status: 200, body: {'success': true, 'message': 'OK', 'data': data});

/// Always signed in; never touches storage or the network.
class _SignedIn extends AuthNotifier {
  _SignedIn(super.ref);

  @override
  Future<void> hydrate() async {
    state = const AuthState(
      status: AuthStatus.authenticated,
      isHydrated: true,
      user: AuthUser(
        id: 'u1',
        email: 'reader@readin.test',
        displayName: 'Reader',
        avatar: '',
        plan: 'free',
        isEmailVerified: true,
      ),
    );
  }
}

void main() {
  group('AccessRefreshScheduler (timing used by the running app)', () {
    late DateTime clock;
    late int refreshes;
    late bool signedIn;
    late AccessRefreshScheduler s;

    setUp(() {
      clock = DateTime(2026, 11, 5, 12);
      refreshes = 0;
      signedIn = true;
      s = AccessRefreshScheduler(
        isAllowed: () => signedIn,
        onRefresh: () => refreshes++,
        now: () => clock,
      );
    });

    Future<void> wait(WidgetTester tester, int seconds) async {
      clock = clock.add(Duration(seconds: seconds));
      await tester.pump(Duration(seconds: seconds));
    }

    testWidgets('refreshes every 45 s while the app is open', (tester) async {
      s.start();
      await wait(tester, 44);
      expect(refreshes, 0);
      await wait(tester, 1);
      expect(refreshes, 1);
      await wait(tester, 45);
      expect(refreshes, 2); // → an admin change shows up in at most ~45 s
      s.stop();
    });

    testWidgets('no refreshes in the background; one right away on resume', (tester) async {
      s.start();
      s.setForeground(false);
      await wait(tester, 180);
      expect(refreshes, 0);
      s.setForeground(true);
      expect(s.request(), isTrue); // didChangeAppLifecycleState(resumed)
      expect(refreshes, 1);
      s.stop();
    });

    testWidgets('never more than once per 15 s', (tester) async {
      expect(s.request(), isTrue);
      await wait(tester, 14);
      expect(s.request(), isFalse);
      await wait(tester, 1);
      expect(s.request(), isTrue);
      expect(refreshes, 2);
    });

    testWidgets('signed out: nothing is asked, and it does not use up the 15 s gap', (tester) async {
      signedIn = false;
      expect(s.request(), isFalse);
      signedIn = true;
      expect(s.request(), isTrue);
      expect(refreshes, 1);
    });

    testWidgets('stop() cancels the timer', (tester) async {
      s.start();
      expect(s.isRunning, isTrue);
      s.stop();
      expect(s.isRunning, isFalse);
      await wait(tester, 100);
      expect(refreshes, 0);
    });
  });

  group('a refresh picks up the admin change', () {
    late String habitsState;
    late bool paymentsOn;
    late bool serverDown;
    late FakeAdapter adapter;
    late ProviderContainer c;

    setUp(() async {
      habitsState = 'full';
      paymentsOn = true;
      serverDown = false;
      adapter = FakeAdapter((o) {
        if (serverDown) return (status: 503, body: {'success': false, 'message': 'asleep'});
        if (o.path.endsWith('/features/me')) {
          return _ok({
            'features': {
              'habits': {'state': habitsState, 'reason': habitsState == 'full' ? '' : 'Switched off'},
            },
          });
        }
        if (o.path.endsWith('/config/public')) {
          return _ok({
            'billing': {'enabled': paymentsOn, 'plans': <Object>[], 'freeLibraryLimit': 10},
          });
        }
        return (status: 404, body: {'success': false, 'message': 'not found'});
      });
      final api = await makeTestApi(adapter); // also resets the mock prefs
      final prefs = await SharedPreferences.getInstance();
      c = ProviderContainer(overrides: [
        storageServiceProvider.overrideWithValue(StorageService(prefs: prefs)),
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => _SignedIn(ref)),
      ]);
    });

    tearDown(() => c.dispose());

    test('feature switched off in admin → the app locks it after the next refresh', () async {
      await c.read(featuresProvider.notifier).refresh();
      expect(c.read(habitsAccessProvider).allowed, isTrue);

      habitsState = 'disabled'; // admin flips the switch
      await c.read(featuresProvider.notifier).refresh();
      expect(c.read(habitsAccessProvider).allowed, isFalse);
      expect(c.read(habitsAccessProvider).reason, 'Switched off');
    });

    test('payments switched off in admin → payment screens hide after the next refresh', () async {
      await c.read(publicConfigProvider.notifier).refresh();
      expect(c.read(billingVisibleProvider), isTrue);

      paymentsOn = false;
      await c.read(publicConfigProvider.notifier).refresh();
      expect(c.read(billingVisibleProvider), isFalse);
    });

    test('server unreachable → the last answer is kept (nobody is locked out)', () async {
      await c.read(featuresProvider.notifier).refresh();
      await c.read(publicConfigProvider.notifier).refresh();
      expect(c.read(habitsAccessProvider).allowed, isTrue);

      serverDown = true; // Render asleep / no network
      await c.read(featuresProvider.notifier).refresh();
      await c.read(publicConfigProvider.notifier).refresh();
      expect(c.read(habitsAccessProvider).allowed, isTrue);
      expect(c.read(billingVisibleProvider), isTrue);
    });
  });
}
