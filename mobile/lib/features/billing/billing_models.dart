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
    this.perDayText = '',
    this.savingsText = '',
  });

  final String id;
  final String name;
  final String description;
  final int priceKobo;
  final int durationDays;
  final String badge;

  /// "less than ₦24 a day" — calculated by the server ('' = admin switched it off / older server).
  final String perDayText;

  /// "2 months free · save ₦1,400" on longer plans ('' = none).
  final String savingsText;

  String get priceText => formatNaira(priceKobo);

  factory PublicPlan.fromJson(Map<String, dynamic> j) => PublicPlan(
        id: '${j['id']}',
        name: '${j['name']}',
        description: '${j['description'] ?? ''}',
        priceKobo: (j['priceKobo'] as num?)?.toInt() ?? 0,
        durationDays: (j['durationDays'] as num?)?.toInt() ?? 30,
        badge: '${j['badge'] ?? ''}',
        perDayText: '${j['perDayText'] ?? ''}',
        savingsText: '${j['savingsText'] ?? ''}',
      );
}

class PublicBilling {
  const PublicBilling({
    this.enabled = false,
    this.plans = const [],
    this.freeLibraryLimit = 10,
    this.trialDays = 0,
    this.headline = '',
    this.reminders = const [],
  });

  /// Payments are switched on by the admin (and Paystack is connected).
  final bool enabled;
  final List<PublicPlan> plans;
  final int freeLibraryLimit;

  /// Free Premium trial length set by the admin (0 = no trial).
  final int trialDays;

  /// Admin's headline for the Premium screen ('' = the standard text).
  final String headline;

  /// Days (relative to the end of Premium) on which the in-app reminder banner appears: e.g. [-5, -2, 0, 3].
  final List<int> reminders;

  /// "10-book" (used in the library banner).
  String get freeLimitText => '$freeLibraryLimit-book';

  factory PublicBilling.fromJson(Map<String, dynamic> j) => PublicBilling(
        enabled: j['enabled'] == true,
        freeLibraryLimit: (j['freeLibraryLimit'] as num?)?.toInt() ?? 10,
        trialDays: (j['trialDays'] as num?)?.toInt() ?? 0,
        headline: '${j['headline'] ?? ''}',
        reminders: [
          for (final r in (j['reminders'] as List? ?? const []))
            if (r is num) r.toInt(),
        ],
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

// ── Premium reminders & trial (S9.2) ─────────────────────────────────────────

enum PremiumReminderKind { before, today, after }

/// What the Home banner says. [step] = the reminder day that is active now (dismissing hides the banner
/// until the next reminder day arrives).
class PremiumReminder {
  const PremiumReminder({required this.kind, required this.days, required this.step, required this.premiumUntil});

  final PremiumReminderKind kind;

  /// Days left (before) or days since it ended (after); 0 for today.
  final int days;
  final int step;
  final DateTime premiumUntil;

  /// Key used to remember "Later" for this reminder day and this end date.
  String get dismissKey => '$step@${premiumUntil.toUtc().toIso8601String()}';

  String get title => switch (kind) {
        PremiumReminderKind.before => 'Premium ends in $days ${days == 1 ? 'day' : 'days'}',
        PremiumReminderKind.today => 'Premium ends today',
        PremiumReminderKind.after => 'We miss you on Premium',
      };

  String get message => switch (kind) {
        PremiumReminderKind.before => 'Renew now and the new time is added on — you lose nothing.',
        PremiumReminderKind.today => 'Renew to keep unlimited books and every Premium feature.',
        PremiumReminderKind.after => 'Your books and notes are all still here. Renew any time to unlock everything again.',
      };
}

const Duration _day = Duration(days: 1);

/// Same rule as the server (billing.logic.ts `inAppReminder`): shown from the first reminder day until 7 days
/// after the last one, never more than 30 days after Premium ended. Returns null = no banner.
PremiumReminder? premiumReminderFor(DateTime? premiumUntil, DateTime now, List<int> offsets) {
  if (premiumUntil == null || offsets.isEmpty) return null;
  final sorted = [...offsets]..sort();
  final end = premiumUntil.toUtc();
  final t = now.toUtc();
  final first = end.add(_day * sorted.first);
  final last = end.add(_day * sorted.last);
  if (t.isBefore(first) || t.isAfter(last.add(_day * 7)) || t.isAfter(end.add(_day * 30))) return null;
  // the latest reminder day that has arrived
  final step = sorted.lastWhere((o) => !t.isBefore(end.add(_day * o)), orElse: () => sorted.first);
  if (t.isBefore(end)) {
    final ms = end.difference(t).inMilliseconds;
    final daysLeft = (ms / _day.inMilliseconds).ceil();
    return daysLeft <= 1
        ? PremiumReminder(kind: PremiumReminderKind.today, days: 0, step: step, premiumUntil: premiumUntil)
        : PremiumReminder(kind: PremiumReminderKind.before, days: daysLeft, step: step, premiumUntil: premiumUntil);
  }
  final daysAgo = t.difference(end).inMilliseconds ~/ _day.inMilliseconds;
  return daysAgo == 0
      ? PremiumReminder(kind: PremiumReminderKind.today, days: 0, step: step, premiumUntil: premiumUntil)
      : PremiumReminder(kind: PremiumReminderKind.after, days: daysAgo, step: step, premiumUntil: premiumUntil);
}

/// The signed-in user's Premium details from `GET /billing/status`.
class BillingStatus {
  const BillingStatus({
    this.trialAvailable = false,
    this.trialDays = 0,
    this.emailReminders = true,
    this.premiumKind,
  });

  final bool trialAvailable;
  final int trialDays;
  final bool emailReminders;

  /// 'paid' | 'trial' | 'gift' | null
  final String? premiumKind;

  BillingStatus copyWith({bool? emailReminders}) => BillingStatus(
        trialAvailable: trialAvailable,
        trialDays: trialDays,
        emailReminders: emailReminders ?? this.emailReminders,
        premiumKind: premiumKind,
      );

  factory BillingStatus.fromJson(Map<String, dynamic> j) {
    final trial = Map<String, dynamic>.from(j['trial'] as Map? ?? const {});
    return BillingStatus(
      trialAvailable: trial['available'] == true,
      trialDays: (trial['days'] as num?)?.toInt() ?? 0,
      emailReminders: j['emailReminders'] != false,
      premiumKind: j['premiumKind'] is String ? j['premiumKind'] as String : null,
    );
  }
}
