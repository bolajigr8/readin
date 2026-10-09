import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/premium_service.dart';

/// Swap this provider (override or edit) to enable real purchases.
final premiumServiceProvider =
    Provider<PremiumService>((ref) => const FakePremiumService());

final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider)?.isPremium ?? false,
);
