import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_result.dart';
import '../../core/distribution.dart';
import '../auth/data/models/auth_user.dart';
import '../auth/providers/auth_providers.dart';
import 'billing_models.dart';

const String _kCache = '@readin/public_config';

/// The server's public settings (is payment visible, the plans in naira).
/// Works offline from the last answer; before the very first answer payments
/// stay hidden.
class PublicConfigNotifier extends StateNotifier<PublicConfig> {
  PublicConfigNotifier(this._ref)
      : super(PublicConfig.fromRaw(_ref.read(storageServiceProvider).readString(_kCache)));

  final Ref _ref;

  Future<void> refresh() async {
    final res = await _ref.read(apiClientProvider).get<String>(
          ApiEndpoints.publicConfig,
          // keep the raw text so it can be cached and parsed by one code path
          parser: (d) => _encode(d),
        );
    final raw = res.dataOrNull;
    if (raw == null || !mounted) return;
    final cfg = PublicConfig.fromRaw(raw);
    if (!cfg.loaded) return;
    state = cfg;
    unawaited(_ref.read(storageServiceProvider).writeString(_kCache, raw));
  }

  static String _encode(Object? d) => jsonEncode(d);
}

final publicConfigProvider =
    StateNotifierProvider<PublicConfigNotifier, PublicConfig>((ref) => PublicConfigNotifier(ref));

/// Show buying screens (plans, prices, Upgrade buttons)? The admin's master switch, and
/// never in the Google Play version (Play payments policy: no Paystack, no "pay elsewhere").
/// Premium users still see their status everywhere.
final billingVisibleProvider = Provider<bool>(
  (ref) => ref.watch(distributionProvider).allowsPaystack && ref.watch(publicConfigProvider).billing.enabled,
);

/// Talks to the payment endpoints.
class BillingApi {
  BillingApi(this._api);
  final ApiClient _api;

  Future<ApiResult<CheckoutSession>> checkout(String planId) => _api.post<CheckoutSession>(
        ApiEndpoints.paymentsCheckout,
        data: {'planId': planId},
        parser: (d) => CheckoutSession.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<ApiResult<PaymentVerification>> verify(String reference) => _api.get<PaymentVerification>(
        ApiEndpoints.paymentsVerify(reference),
        parser: (d) => PaymentVerification.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<ApiResult<AuthUser>> me() => _api.get<AuthUser>(
        ApiEndpoints.usersMe,
        parser: (d) => AuthUser.fromJson(Map<String, dynamic>.from((d as Map)['user'] as Map)),
      );

  Future<ApiResult<void>> resendVerification(String email) => _api.post<void>(
        ApiEndpoints.resendVerification,
        data: {'email': email},
        parser: (_) {},
      );
}

final billingApiProvider = Provider<BillingApi>((ref) => BillingApi(ref.watch(apiClientProvider)));

/// Pulls the signed-in user (plan + Premium end date) fresh from the server:
/// `await ref.read(refreshUserProvider)();`
final refreshUserProvider = Provider<Future<void> Function()>((ref) => () => _refreshCurrentUser(ref));

Future<void> _refreshCurrentUser(Ref ref) async {
  if (!ref.read(authProvider).isAuthenticated) return;
  final fresh = (await ref.read(billingApiProvider).me()).dataOrNull;
  if (fresh == null) return;
  final current = ref.read(authProvider).user;
  // keep the avatar/name the phone already has if the server sends none
  await ref.read(authProvider.notifier).setUser(
        current == null
            ? fresh
            : AuthUser(
                id: fresh.id,
                email: fresh.email,
                displayName: fresh.displayName.isEmpty ? current.displayName : fresh.displayName,
                avatar: fresh.avatar.isEmpty ? current.avatar : fresh.avatar,
                plan: fresh.plan,
                isEmailVerified: fresh.isEmailVerified,
                premiumUntil: fresh.premiumUntil,
              ),
      );
}
