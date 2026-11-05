import 'dart:convert';

/// How a premium/trial feature may be used by THIS user right now
/// (decided by the server; see `entitlements.logic.ts`).
enum AccessState { full, trial, trialAvailable, expired, locked, disabled, unknown }

AccessState _state(String? s) => switch (s) {
      'full' => AccessState.full,
      'trial' => AccessState.trial,
      'trial_available' => AccessState.trialAvailable,
      'expired' => AccessState.expired,
      'locked' => AccessState.locked,
      'disabled' => AccessState.disabled,
      _ => AccessState.unknown,
    };

String _stateName(AccessState s) => switch (s) {
      AccessState.full => 'full',
      AccessState.trial => 'trial',
      AccessState.trialAvailable => 'trial_available',
      AccessState.expired => 'expired',
      AccessState.locked => 'locked',
      AccessState.disabled => 'disabled',
      AccessState.unknown => 'unknown',
    };

class FeatureAccess {
  const FeatureAccess({
    this.state = AccessState.unknown,
    this.reason = '',
    this.trialEndsAt,
  });

  final AccessState state;
  final String reason;
  final DateTime? trialEndsAt;

  /// We could not ask the server yet (offline / server asleep). The app never
  /// locks people out because OUR server is unreachable.
  bool get isUnknown => state == AccessState.unknown;

  bool get allowed =>
      state == AccessState.full || state == AccessState.trial || state == AccessState.unknown;

  bool get canStartTrial => state == AccessState.trialAvailable;

  /// Days left in the trial, counted at [now] (works offline from the cached end date).
  int? daysLeft([DateTime? now]) {
    final end = trialEndsAt;
    if (state != AccessState.trial || end == null) return null;
    final ms = end.difference(now ?? DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / Duration.millisecondsPerDay).ceil();
  }

  /// A cached "trial" whose end date has passed is expired, even offline.
  FeatureAccess evaluate([DateTime? now]) {
    if (state == AccessState.trial && trialEndsAt != null && !(now ?? DateTime.now()).isBefore(trialEndsAt!)) {
      return FeatureAccess(state: AccessState.expired, reason: 'Your free trial has ended.', trialEndsAt: trialEndsAt);
    }
    return this;
  }

  Map<String, dynamic> toJson() => {
        'state': _stateName(state),
        'reason': reason,
        if (trialEndsAt != null) 'trialEndsAt': trialEndsAt!.toIso8601String(),
      };

  factory FeatureAccess.fromJson(Map<String, dynamic> j) => FeatureAccess(
        state: _state(j['state'] as String?),
        reason: (j['reason'] ?? '') as String,
        trialEndsAt: DateTime.tryParse('${j['trialEndsAt'] ?? ''}'),
      );
}

/// All features for the signed-in user.
class FeaturesState {
  const FeaturesState({this.features = const {}, this.loaded = false});

  final Map<String, FeatureAccess> features;

  /// An answer (server or cache) has arrived at least once.
  final bool loaded;

  FeatureAccess of(String key) => (features[key] ?? const FeatureAccess()).evaluate();

  String encode() => jsonEncode({for (final e in features.entries) e.key: e.value.toJson()});

  static FeaturesState decode(String? raw) {
    if (raw == null || raw.isEmpty) return const FeaturesState();
    try {
      final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return FeaturesState(
        features: {
          for (final e in j.entries)
            e.key: FeatureAccess.fromJson(Map<String, dynamic>.from(e.value as Map)),
        },
        loaded: true,
      );
    } catch (_) {
      return const FeaturesState();
    }
  }
}
