import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../auth/providers/auth_providers.dart';
import 'feature_models.dart';

const String _kCache = '@readin/features_cache';

class FeaturesNotifier extends StateNotifier<FeaturesState> {
  FeaturesNotifier(this._ref)
      : super(FeaturesState.decode(_ref.read(storageServiceProvider).readString(_kCache)));

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  /// Asks the server (call after sign-in and when the app comes back).
  /// Network trouble keeps the cached answer — people are never locked out
  /// because the server is asleep.
  Future<void> refresh() async {
    if (!_ref.read(authProvider).isAuthenticated) return;
    final res = await _api.get<Map<String, FeatureAccess>>(
      ApiEndpoints.featuresMe,
      parser: (d) {
        final m = Map<String, dynamic>.from(d as Map);
        final f = Map<String, dynamic>.from(m['features'] as Map? ?? const {});
        return {
          for (final e in f.entries)
            e.key: FeatureAccess.fromJson(Map<String, dynamic>.from(e.value as Map)),
        };
      },
    );
    final map = res.dataOrNull;
    if (map != null && mounted) {
      state = FeaturesState(features: map, loaded: true);
      _save();
      return;
    }
    // An old server (no /features yet) → everything stays available.
    if (!state.loaded && mounted) state = const FeaturesState(loaded: true);
  }

  /// Starts the free trial (the server keeps the clock; idempotent).
  Future<bool> startTrial(String key) async {
    final res = await _api.post<FeatureAccess>(
      ApiEndpoints.featureStartTrial(key),
      parser: (d) => FeatureAccess.fromJson(
        Map<String, dynamic>.from((d as Map)['access'] as Map),
      ),
    );
    final access = res.dataOrNull;
    if (access == null || !mounted) return false;
    state = FeaturesState(features: {...state.features, key: access}, loaded: true);
    _save();
    return true;
  }

  void _save() => unawaited(_ref.read(storageServiceProvider).writeString(_kCache, state.encode()));

  /// After sign-out the next user must not inherit this answer.
  void clear() {
    state = const FeaturesState();
    unawaited(_ref.read(storageServiceProvider).writeString(_kCache, ''));
  }
}

final featuresProvider =
    StateNotifierProvider<FeaturesNotifier, FeaturesState>((ref) => FeaturesNotifier(ref));

/// Access to the habit tracker (trial / premium / expired…).
final habitsAccessProvider = Provider<FeatureAccess>(
  (ref) => ref.watch(featuresProvider).of('habits'),
);
