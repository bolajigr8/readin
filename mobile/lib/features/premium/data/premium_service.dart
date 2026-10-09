/// Outcome of a purchase / restore attempt.
enum PremiumResult {
  /// Entitlement `premium` is active.
  success,

  /// The user closed the store sheet (not an error).
  cancelled,

  /// No store integration in this build (RN: "available in production build").
  unavailable,

  /// Store / network failure.
  failed,

  /// Restore finished but nothing to restore.
  nothingToRestore,
}

class PremiumPackage {
  const PremiumPackage({
    required this.id,
    required this.title,
    required this.price,
    required this.period,
    this.savings,
  });

  final String id;
  final String title;
  final String price;
  final String period;
  final String? savings;
}

class PremiumFeature {
  const PremiumFeature(this.label, this.free, this.premium);
  final String label;
  final String free;
  final String premium;
}

const List<PremiumPackage> kPremiumPackages = [
  PremiumPackage(id: 'premium_monthly', title: 'Monthly', price: '\$4.99', period: '/month'),
  PremiumPackage(
    id: 'premium_annual',
    title: 'Annual',
    price: '\$39.99',
    period: '/year',
    savings: 'Save 33%',
  ),
];

const List<PremiumFeature> kPremiumFeatures = [
  PremiumFeature('Unlimited books', '10 books', 'Unlimited'),
  PremiumFeature('Annotations', '20 highlights', 'Unlimited'),
  PremiumFeature('Offline reading', '✓', '✓'),
  PremiumFeature('Audio TTS', 'Preview only', 'Full chapters'),
  PremiumFeature('Advanced stats', '✗', '✓'),
  PremiumFeature('Priority support', '✗', '✓'),
];

/// Premium is not on sale yet: Start Premium / Restore show a "Coming soon"
/// dialog. Flip to `false` when purchases are wired (see PHASE_10_NOTES).
const bool kPremiumComingSoon = true;

/// Store integration boundary. The default build uses [FakePremiumService];
/// a RevenueCat implementation (entitlement `premium`, public SDK key via
/// `--dart-define`) plugs in here without touching any UI (see PHASE_10_NOTES).
abstract class PremiumService {
  Future<PremiumResult> purchase(String packageId);
  Future<PremiumResult> restore();
}

/// Default: mirrors RN, where purchases are not wired in development builds.
class FakePremiumService implements PremiumService {
  const FakePremiumService();

  @override
  Future<PremiumResult> purchase(String packageId) async => PremiumResult.unavailable;

  @override
  Future<PremiumResult> restore() async => PremiumResult.unavailable;
}
