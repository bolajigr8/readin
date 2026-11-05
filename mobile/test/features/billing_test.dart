import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/features/auth/data/models/auth_user.dart';
import 'package:readin_flutter/features/billing/billing_models.dart';
import 'package:readin_flutter/features/billing/billing_providers.dart';

import '../helpers/test_rig.dart';

TestReply _ok(Object data) => (status: 200, body: {'success': true, 'message': 'OK', 'data': data});

void main() {
  group('naira formatting', () {
    test('formatNaira from kobo', () {
      expect(formatNaira(150000), '₦1,500');
      expect(formatNaira(150050), '₦1,500.50');
      expect(formatNaira(5000), '₦50');
      expect(formatNaira(123456789), '₦1,234,567.89');
      expect(formatNaira(0), '₦0');
    });

    test('durationText', () {
      expect(durationText(30), '30 days (about a month)');
      expect(durationText(365), '1 year');
      expect(durationText(730), '2 years');
      expect(durationText(7), '1 week');
      expect(durationText(90), '90 days');
    });
  });

  group('public config', () {
    final raw = jsonEncode({
      'billing': {
        'enabled': true,
        'currency': 'NGN',
        'freeLibraryLimit': 12,
        'plans': [
          {'id': 'monthly', 'name': 'Monthly', 'description': '', 'priceKobo': 150000, 'durationDays': 30, 'badge': ''},
          {'id': 'yearly', 'name': 'Yearly', 'description': 'Save', 'priceKobo': 1500000, 'durationDays': 365, 'badge': 'Best value'},
        ],
      },
    });

    test('parses plans, prices and the free limit', () {
      final c = PublicConfig.fromRaw(raw);
      expect(c.loaded, isTrue);
      expect(c.billing.enabled, isTrue);
      expect(c.billing.freeLibraryLimit, 12);
      expect(c.billing.freeLimitText, '12-book');
      expect(c.billing.plans.map((p) => p.id), ['monthly', 'yearly']);
      expect(c.billing.plans.last.priceText, '₦15,000');
      expect(c.billing.plans.last.badge, 'Best value');
    });

    test('before the first answer (or on garbage) payments stay hidden', () {
      expect(PublicConfig.fromRaw(null).billing.enabled, isFalse);
      expect(PublicConfig.fromRaw('').loaded, isFalse);
      expect(PublicConfig.fromRaw('not json').billing.enabled, isFalse);
      expect(const PublicConfig().billing.plans, isEmpty);
    });
  });

  group('Paystack return page detection', () {
    final api = Uri.parse('https://readin-ehzw.onrender.com/api/v1');

    test('finds the reference on our callback page only', () {
      expect(
        paymentCallbackReference(Uri.parse('https://readin-ehzw.onrender.com/payment/callback?trxref=rdn_1&reference=rdn_1'), api),
        'rdn_1',
      );
      expect(paymentCallbackReference(Uri.parse('https://readin-ehzw.onrender.com/payment/callback?trxref=abc'), api), 'abc');
      expect(paymentCallbackReference(Uri.parse('https://readin-ehzw.onrender.com/payment/callback'), api), '');
      // other hosts / paths are NOT ours
      expect(paymentCallbackReference(Uri.parse('https://evil.com/payment/callback?reference=x'), api), isNull);
      expect(paymentCallbackReference(Uri.parse('https://checkout.paystack.com/abc'), api), isNull);
      expect(paymentCallbackReference(Uri.parse('https://readin-ehzw.onrender.com/api/v1/health'), api), isNull);
    });
  });

  group('user + premium end date', () {
    test('AuthUser keeps premiumUntil through json and copyWith', () {
      final u = AuthUser.fromJson({
        'id': '1',
        'email': 'a@b.c',
        'displayName': 'Ada',
        'plan': 'premium',
        'premiumUntil': '2026-11-24T10:00:00.000Z',
        'isEmailVerified': true,
      });
      expect(u.isPremium, isTrue);
      expect(u.premiumUntil!.toUtc().day, 24);
      final back = AuthUser.fromJson(u.toJson());
      expect(back.premiumUntil, u.premiumUntil);
      expect(u.copyWith(plan: 'free').premiumUntil, u.premiumUntil);
      expect(u.copyWith(clearPremiumUntil: true).premiumUntil, isNull);
      expect(AuthUser.fromJson({'id': '2', 'email': 'x@y.z'}).premiumUntil, isNull);
    });
  });

  group('BillingApi', () {
    test('checkout sends only the plan id and returns the Paystack page', () async {
      final adapter = FakeAdapter((o) => _ok({
            'authorizationUrl': 'https://checkout.paystack.com/xyz',
            'reference': 'rdn_abc',
            'amountText': '₦1,500',
            'planName': 'Monthly',
          }));
      final api = BillingApi(await makeTestApi(adapter));
      final r = await api.checkout('monthly');
      final s = r.dataOrNull!;
      expect(s.authorizationUrl, 'https://checkout.paystack.com/xyz');
      expect(s.reference, 'rdn_abc');
      final sent = adapter.requests.single;
      expect(sent.path, endsWith('/payments/checkout'));
      expect(sent.data, {'planId': 'monthly'}); // never a price
    });

    test('verify maps success / pending / failed', () async {
      for (final (status, expected) in [
        ('success', PaymentStatus.success),
        ('pending', PaymentStatus.pending),
        ('failed', PaymentStatus.failed),
      ]) {
        final adapter = FakeAdapter((o) => _ok({'status': status, 'plan': 'premium', 'premiumUntil': '2026-12-01T00:00:00Z', 'reason': 'x'}));
        final r = await BillingApi(await makeTestApi(adapter)).verify('rdn_1');
        expect(r.dataOrNull!.status, expected, reason: status);
        expect(adapter.requests.single.path, endsWith('/payments/verify/rdn_1'));
      }
    });

    test('checkout failure keeps the server message (payments off / no plan)', () async {
      final adapter = FakeAdapter((o) => (status: 403, body: {'success': false, 'message': 'Payments are not available right now.'}));
      final r = await BillingApi(await makeTestApi(adapter)).checkout('monthly');
      expect(r.dataOrNull, isNull);
      expect(r.exceptionOrNull!.message, contains('not available'));
    });

    test('me() returns the fresh plan and end date', () async {
      final adapter = FakeAdapter((o) => _ok({
            'user': {'id': '9', 'email': 'a@b.c', 'displayName': 'Ada', 'avatar': '', 'plan': 'premium', 'premiumUntil': '2026-11-24T10:00:00Z', 'isEmailVerified': true},
          }));
      final u = (await BillingApi(await makeTestApi(adapter)).me()).dataOrNull!;
      expect(u.plan, 'premium');
      expect(u.premiumUntil, isNotNull);
    });

    test('resend verification posts the e-mail', () async {
      final adapter = FakeAdapter((o) => _ok({}));
      await BillingApi(await makeTestApi(adapter)).resendVerification('ada@example.com');
      expect(adapter.requests.single.path, endsWith('/auth/resend-verification'));
      expect(adapter.requests.single.data, {'email': 'ada@example.com'});
    });
  });
}
