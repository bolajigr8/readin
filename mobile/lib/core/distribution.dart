import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which version of ReadIn this is. Decided at BUILD time by the Android flavor
/// (`flutter build … --flavor play|direct`; `default-flavor: direct` in pubspec.yaml):
///
/// * [direct] — the APK from our website: Paystack payments, "On this phone" whole-device scan.
/// * [play]   — the Google Play version: NO Paystack, no prices or links to pay elsewhere
///   (Google Play payments policy), no all-files permission. Premium bought elsewhere
///   still works after sign-in (it belongs to the account). Google Play Billing comes later.
enum Distribution {
  direct,
  play;

  /// Paystack checkout inside the app is allowed only outside Google Play.
  bool get allowsPaystack => this == Distribution.direct;

  /// Whole-phone scan needs MANAGE_EXTERNAL_STORAGE, which only the direct flavor declares.
  bool get allowsWholePhoneScan => this == Distribution.direct;

  /// Sent to the server on every request (`X-App-Distribution`).
  String get wireName => name;
}

/// The distribution of THIS build (unknown/absent flavor → direct, e.g. `flutter test`).
Distribution distributionFromFlavor(String? flavor) =>
    flavor == 'play' ? Distribution.play : Distribution.direct;

final Distribution kDistribution = distributionFromFlavor(appFlavor);

/// Riverpod handle so widget tests can pretend to be the Play version.
final distributionProvider = Provider<Distribution>((ref) => kDistribution);
