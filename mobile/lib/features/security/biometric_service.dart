import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

enum BioResult {
  /// The finger / face was accepted.
  success,

  /// The person cancelled or the scan did not match.
  failed,

  /// Too many attempts — the phone locked the sensor for a while.
  lockedOut,

  /// No sensor, nothing enrolled, or the system said no.
  unavailable,
}

/// Fingerprint / face check (S4). An interface so tests can use a fake.
abstract class BiometricService {
  /// The phone has a sensor AND at least one fingerprint / face is set up.
  Future<bool> isAvailable();

  Future<BioResult> authenticate(String reason);
}

class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<BioResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true, // "Use password instead" is our own button (it signs out)
        persistAcrossBackgrounding: true,
      );
      return ok ? BioResult.success : BioResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.temporaryLockout || LocalAuthExceptionCode.biometricLockout => BioResult.lockedOut,
        LocalAuthExceptionCode.noBiometricHardware || LocalAuthExceptionCode.noBiometricsEnrolled => BioResult.unavailable,
        _ => BioResult.failed,
      };
    } on PlatformException {
      return BioResult.unavailable;
    }
  }
}

final biometricServiceProvider = Provider<BiometricService>((ref) => LocalAuthBiometricService());
