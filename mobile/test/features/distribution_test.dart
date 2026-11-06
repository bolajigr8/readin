// The two versions of ReadIn (DECISIONS #17):
//   direct = APK from our website → Paystack + whole-phone scan
//   play   = Google Play        → no Paystack/prices/"pay elsewhere", no all-files scan
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readin_flutter/core/api/api_client.dart';
import 'package:readin_flutter/core/distribution.dart';
import 'package:readin_flutter/core/services/storage_service.dart';
import 'package:readin_flutter/features/auth/providers/auth_providers.dart';
import 'package:readin_flutter/features/billing/billing_providers.dart';

import '../helpers/test_rig.dart';

TestReply _ok(Object data) => (status: 200, body: {'success': true, 'message': 'OK', 'data': data});

void main() {
  group('which version is this build', () {
    test('flavor "play" → play; anything else (incl. no flavor) → direct', () {
      expect(distributionFromFlavor('play'), Distribution.play);
      expect(distributionFromFlavor('direct'), Distribution.direct);
      expect(distributionFromFlavor(null), Distribution.direct);
      expect(distributionFromFlavor('something'), Distribution.direct);
    });

    test('only the APK version may sell with Paystack or scan the whole phone', () {
      expect(Distribution.direct.allowsPaystack, isTrue);
      expect(Distribution.direct.allowsWholePhoneScan, isTrue);
      expect(Distribution.play.allowsPaystack, isFalse);
      expect(Distribution.play.allowsWholePhoneScan, isFalse);
    });

    test('tests run without a flavor → direct', () {
      expect(kDistribution, Distribution.direct);
    });
  });

  test('every API call tells the server which version it is (X-App-Distribution)', () async {
    final adapter = FakeAdapter((_) => _ok({}));
    final api = await makeTestApi(adapter);
    await api.get<Object?>('/config/public');
    expect(adapter.requests.single.headers['X-App-Distribution'], 'direct');
  });

  group('buying screens (billingVisibleProvider)', () {
    late bool paymentsOn;

    Future<ProviderContainer> container(Distribution d) async {
      final adapter = FakeAdapter((o) {
        if (o.path.endsWith('/config/public')) {
          return _ok({
            'billing': {
              'enabled': paymentsOn,
              'freeLibraryLimit': 10,
              'plans': [
                {'id': 'monthly', 'name': 'Monthly', 'description': '', 'priceKobo': 80000, 'durationDays': 30, 'badge': ''},
              ],
            },
          });
        }
        return (status: 404, body: {'success': false, 'message': 'not found'});
      });
      final ApiClient api = await makeTestApi(adapter);
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        storageServiceProvider.overrideWithValue(StorageService(prefs: prefs)),
        apiClientProvider.overrideWithValue(api),
        distributionProvider.overrideWithValue(d),
      ]);
      addTearDown(c.dispose);
      await c.read(publicConfigProvider.notifier).refresh();
      return c;
    }

    test('APK version + payments ON in admin → Upgrade / plans are shown', () async {
      paymentsOn = true;
      final c = await container(Distribution.direct);
      expect(c.read(publicConfigProvider).billing.enabled, isTrue);
      expect(c.read(billingVisibleProvider), isTrue);
    });

    test('APK version + payments OFF in admin → hidden', () async {
      paymentsOn = false;
      final c = await container(Distribution.direct);
      expect(c.read(billingVisibleProvider), isFalse);
    });

    test('Google Play version → ALWAYS hidden, even with payments ON (no Paystack in Play)', () async {
      paymentsOn = true;
      final c = await container(Distribution.play);
      expect(c.read(publicConfigProvider).billing.enabled, isTrue, reason: 'the server says payments are on');
      expect(c.read(billingVisibleProvider), isFalse);
    });
  });
}
