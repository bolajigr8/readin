import 'dart:convert';

/// "₦1,500" / "₦1,500.50" from kobo (₦1 = 100 kobo).
String formatNaira(int kobo) {
  final naira = kobo ~/ 100;
  final rest = kobo % 100;
  final whole = naira.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '₦$whole${rest == 0 ? '' : '.${rest.toString().padLeft(2, '0')}'}';
}

/// "30 days" · "about a month" · "1 year"
String durationText(int days) {
  if (days == 30) return '30 days (about a month)';
  if (days == 365) return '1 year';
  if (days % 365 == 0) return '${days ~/ 365} years';
  if (days == 7) return '1 week';
  return '$days days';
}

/// A plan the admin created (only ACTIVE plans reach the app).
class PublicPlan {
  const PublicPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.priceKobo,
    required this.durationDays,
    required this.badge,
  });

  final String id;
  final String name;
  final String description;
  final int priceKobo;
  final int durationDays;
  final String badge;

  String get priceText => formatNaira(priceKobo);

  factory PublicPlan.fromJson(Map<String, dynamic> j) => PublicPlan(
        id: '${j['id']}',
        name: '${j['name']}',
        description: '${j['description'] ?? ''}',
        priceKobo: (j['priceKobo'] as num?)?.toInt() ?? 0,
        durationDays: (j['durationDays'] as num?)?.toInt() ?? 30,
        badge: '${j['badge'] ?? ''}',
      );
}

class PublicBilling {
  const PublicBilling({this.enabled = false, this.plans = const [], this.freeLibraryLimit = 10});

  /// Payments are switched on by the admin (and Paystack is connected).
  final bool enabled;
  final List<PublicPlan> plans;
  final int freeLibraryLimit;

  /// "10-book" (used in the library banner).
  String get freeLimitText => '$freeLibraryLimit-book';

  factory PublicBilling.fromJson(Map<String, dynamic> j) => PublicBilling(
        enabled: j['enabled'] == true,
        freeLibraryLimit: (j['freeLibraryLimit'] as num?)?.toInt() ?? 10,
        plans: [
          for (final p in (j['plans'] as List? ?? const []))
            if (p is Map) PublicPlan.fromJson(Map<String, dynamic>.from(p)),
        ],
      );
}

/// What the server tells every phone about itself (no secrets, no login needed).
class PublicConfig {
  const PublicConfig({this.billing = const PublicBilling(), this.loaded = false});

  final PublicBilling billing;
  final bool loaded;

  static PublicConfig fromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return const PublicConfig();
    try {
      final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return PublicConfig(
        billing: PublicBilling.fromJson(Map<String, dynamic>.from(j['billing'] as Map? ?? const {})),
        loaded: true,
      );
    } catch (_) {
      return const PublicConfig();
    }
  }
}

/// Paystack page to open + the reference to verify afterwards.
class CheckoutSession {
  const CheckoutSession({
    required this.authorizationUrl,
    required this.reference,
    required this.amountText,
    required this.planName,
  });

  final String authorizationUrl;
  final String reference;
  final String amountText;
  final String planName;

  factory CheckoutSession.fromJson(Map<String, dynamic> j) => CheckoutSession(
        authorizationUrl: '${j['authorizationUrl']}',
        reference: '${j['reference']}',
        amountText: '${j['amountText'] ?? ''}',
        planName: '${j['planName'] ?? ''}',
      );
}

enum PaymentStatus { success, pending, failed }

class PaymentVerification {
  const PaymentVerification({required this.status, this.premiumUntil, this.reason = ''});

  final PaymentStatus status;
  final DateTime? premiumUntil;
  final String reason;

  factory PaymentVerification.fromJson(Map<String, dynamic> j) => PaymentVerification(
        status: switch (j['status']) {
          'success' => PaymentStatus.success,
          'failed' => PaymentStatus.failed,
          _ => PaymentStatus.pending,
        },
        premiumUntil: DateTime.tryParse('${j['premiumUntil'] ?? ''}'),
        reason: '${j['reason'] ?? ''}',
      );
}

/// Is [url] the page Paystack sends the customer back to after paying?
/// (our server's `/payment/callback`). Returns the payment reference or null.
String? paymentCallbackReference(Uri url, Uri apiBase) {
  if (url.host != apiBase.host || !url.path.endsWith('/payment/callback')) return null;
  final ref = url.queryParameters['reference'] ?? url.queryParameters['trxref'];
  return (ref == null || ref.isEmpty) ? '' : ref;
}
