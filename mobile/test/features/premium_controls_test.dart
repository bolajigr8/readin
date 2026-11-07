// S9.2 — Premium controls in the app: price hooks, free trial, reminder banner, reminder e-mail switch.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readin_flutter/core/services/storage_service.dart';
import 'package:readin_flutter/features/auth/data/models/auth_user.dart';
import 'package:readin_flutter/features/auth/providers/auth_providers.dart';
import 'package:readin_flutter/features/billing/billing_models.dart';
import 'package:readin_flutter/features/billing/billing_providers.dart';
import 'package:readin_flutter/features/billing/premium_reminder_banner.dart';

import '../helpers/test_rig.dart';

TestReply _ok(Object data) => (status: 200, body: {'success': true, 'message': 'OK', 'data': data});

void main() {
  group('public config (S9.2 fields)', () {
    test('reads hooks, trial, headline and reminder days', () {
      final c = PublicConfig.fromRaw(jsonEncode({
        'billing': {
          'enabled': true,
          'trialDays': 7,
          'headline': 'Read without limits',
          'reminders': [-5, -2, 0, 3],
          'plans': [
            {'id': 'monthly', 'name': 'Monthly', 'priceKobo': 70000, 'durationDays': 30, 'perDayText': 'less than ₦24 a day', 'savingsText': ''},
            {'id': 'yearly', 'name': 'Yearly', 'priceKobo': 700000, 'durationDays': 365, 'perDayText': 'less than ₦20 a day', 'savingsText': '2 months free · save ₦1,400'},
          ],
        },
      }));
      expect(c.billing.trialDays, 7);
      expect(c.billing.headline, 'Read without limits');
      expect(c.billing.reminders, [-5, -2, 0, 3]);
      expect(c.billing.plans.first.perDayText, 'less than ₦24 a day');
      expect(c.billing.plans.last.savingsText, '2 months free · save ₦1,400');
    });

    test('an older server without the new fields → no trial, no hooks, no banner days', () {
      final c = PublicConfig.fromRaw(jsonEncode({
        'billing': {
          'enabled': true,
          'plans': [
            {'id': 'monthly', 'name': 'Monthly', 'priceKobo': 70000, 'durationDays': 30},
          ],
        },
      }));
      expect(c.billing.trialDays, 0);
      expect(c.billing.headline, '');
      expect(c.billing.reminders, isEmpty);
      expect(c.billing.plans.single.perDayText, '');
    });
  });

  group('reminder banner rule (same as the server)', () {
    final end = DateTime.utc(2026, 12, 1, 12);
    DateTime at(int days, [int hours = 0]) => end.add(Duration(days: days, hours: hours));
    const offs = [-5, -2, 0, 3];

    test('nothing before the first reminder day', () => expect(premiumReminderFor(end, at(-6), offs), isNull));

    test('5 days left on the first reminder day', () {
      final r = premiumReminderFor(end, at(-5), offs)!;
      expect(r.kind, PremiumReminderKind.before);
      expect(r.days, 5);
      expect(r.step, -5);
      expect(r.title, 'Premium ends in 5 days');
    });

    test('the step changes on the next reminder day (so "Later" only hides until then)', () {
      expect(premiumReminderFor(end, at(-4), offs)!.step, -5);
      expect(premiumReminderFor(end, at(-2), offs)!.step, -2);
      expect(premiumReminderFor(end, at(-4), offs)!.dismissKey, isNot(premiumReminderFor(end, at(-2), offs)!.dismissKey));
    });

    test('last hours → today; after → "we miss you"', () {
      expect(premiumReminderFor(end, at(0, -3), offs)!.kind, PremiumReminderKind.today);
      final after = premiumReminderFor(end, at(3, 1), offs)!;
      expect(after.kind, PremiumReminderKind.after);
      expect(after.days, 3);
      expect(after.title, 'We miss you on Premium');
    });

    test('gone a week after the last reminder day; no days / no end date → nothing', () {
      expect(premiumReminderFor(end, at(11), offs), isNull);
      expect(premiumReminderFor(end, at(-1), const []), isNull);
      expect(premiumReminderFor(null, at(-1), offs), isNull);
    });

    test('a renewal (new end date) gets a new dismiss key', () {
      final renewed = end.add(const Duration(days: 30));
      expect(
        premiumReminderFor(renewed, renewed.subtract(const Duration(days: 5)), offs)!.dismissKey,
        isNot(premiumReminderFor(end, at(-5), offs)!.dismissKey),
      );
    });
  });

  group('BillingApi (trial + reminder switch)', () {
    final statusJson = {
      'plan': 'free',
      'premiumUntil': null,
      'premiumKind': null,
      'emailReminders': false,
      'trial': {'days': 7, 'available': true, 'usedAt': null},
      'reminder': null,
    };

    test('status() parses trial and the e-mail switch', () async {
      final adapter = FakeAdapter((o) => _ok(statusJson));
      final s = (await BillingApi(await makeTestApi(adapter)).status()).dataOrNull!;
      expect(s.trialAvailable, isTrue);
      expect(s.trialDays, 7);
      expect(s.emailReminders, isFalse);
      expect(adapter.requests.single.path, endsWith('/billing/status'));
    });

    test('startTrial() posts to /billing/trial and sends nothing else', () async {
      final adapter = FakeAdapter((o) => _ok({...statusJson, 'plan': 'premium', 'premiumKind': 'trial'}));
      final s = (await BillingApi(await makeTestApi(adapter)).startTrial()).dataOrNull!;
      expect(s.premiumKind, 'trial');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, endsWith('/billing/trial'));
    });

    test('startTrial() keeps the server message when the trial was already used', () async {
      final adapter = FakeAdapter((o) => (status: 409, body: {'success': false, 'message': 'You have already used your free trial, or Premium is already active.'}));
      final r = await BillingApi(await makeTestApi(adapter)).startTrial();
      expect(r.dataOrNull, isNull);
      expect(r.exceptionOrNull!.message, contains('already used'));
    });

    test('setEmailReminders() PATCHes {email}', () async {
      final adapter = FakeAdapter((o) => _ok({'emailReminders': true}));
      await BillingApi(await makeTestApi(adapter)).setEmailReminders(true);
      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, endsWith('/billing/reminders'));
      expect(req.data, {'email': true});
    });
  });

  group('Home reminder banner', () {
    final end = DateTime.utc(2026, 12, 1, 12);
    final user = AuthUser(
      id: '1',
      email: 'a@b.c',
      displayName: 'Ada',
      avatar: '',
      plan: 'premium',
      isEmailVerified: true,
      premiumUntil: end,
    );

    Future<StorageService> storage() async {
      SharedPreferences.setMockInitialValues({});
      final s = StorageService(prefs: await SharedPreferences.getInstance());
      await s.writeString('@readin/public_config', jsonEncode({
        'billing': {'enabled': true, 'reminders': [-5, -2, 0, 3], 'plans': []},
      }));
      return s;
    }

    Widget app(StorageService s, {required bool canBuy, required DateTime now}) => ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(s),
            currentUserProvider.overrideWithValue(user),
            billingVisibleProvider.overrideWithValue(canBuy),
          ],
          child: MaterialApp(home: Scaffold(body: PremiumReminderBanner(now: now))),
        );

    testWidgets('shows "ends in 5 days" with Renew; Later hides it until the next reminder day', (tester) async {
      final s = await storage();
      await tester.pumpWidget(app(s, canBuy: true, now: end.subtract(const Duration(days: 5))));
      expect(find.text('Premium ends in 5 days'), findsOneWidget);
      expect(find.text('Renew'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pump();
      expect(find.byKey(const ValueKey('premium-reminder-banner')), findsNothing);

      // still hidden later on the same reminder step (new widget, same phone storage)
      await tester.pumpWidget(app(s, canBuy: true, now: end.subtract(const Duration(days: 4))));
      expect(find.byKey(const ValueKey('premium-reminder-banner')), findsNothing);

      // the next reminder day (2 days left) shows it again
      await tester.pumpWidget(Container());
      await tester.pumpWidget(app(s, canBuy: true, now: end.subtract(const Duration(days: 2))));
      expect(find.text('Premium ends in 2 days'), findsOneWidget);
    });

    testWidgets('never shown where buying is not possible (Play version / payments off)', (tester) async {
      final s = await storage();
      await tester.pumpWidget(app(s, canBuy: false, now: end.subtract(const Duration(days: 5))));
      expect(find.byKey(const ValueKey('premium-reminder-banner')), findsNothing);
    });

    testWidgets('no banner far from the end date', (tester) async {
      final s = await storage();
      await tester.pumpWidget(app(s, canBuy: true, now: end.subtract(const Duration(days: 20))));
      expect(find.byKey(const ValueKey('premium-reminder-banner')), findsNothing);
    });
  });
}
