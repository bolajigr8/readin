import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_result.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/reading_stats.dart';

Future<ApiResult<ReadingStats>> fetchReadingStats(ApiClient api) =>
    api.get<ReadingStats>(
      ApiEndpoints.progressStats,
      parser: (d) => ReadingStats.fromJson(Map<String, dynamic>.from(d as Map)),
    );

/// Reading stats, cached 5 minutes after the last listener leaves (RN
/// `staleTime`), per user. Pull-to-refresh: `ref.invalidate(readingStatsProvider)`.
final readingStatsProvider = FutureProvider.autoDispose<ReadingStats>((ref) async {
  final userId = ref.watch(authProvider.select((s) => s.user?.id));

  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);

  if (userId == null) return ReadingStats.zero;
  return fetchReadingStats(ref.watch(apiClientProvider)).unwrap();
});

/// RN `settingsStore`: values persisted through `StorageService`.
class AppSettings {
  const AppSettings({
    required this.defaultFontSize,
    required this.defaultTheme,
    required this.notificationsEnabled,
    required this.autoDownloadEpub,
  });

  final double defaultFontSize;

  /// `'light'` | `'dark'` | `'sepia'`.
  final String defaultTheme;
  final bool notificationsEnabled;
  final bool autoDownloadEpub;

  AppSettings copyWith({
    double? defaultFontSize,
    String? defaultTheme,
    bool? notificationsEnabled,
    bool? autoDownloadEpub,
  }) =>
      AppSettings(
        defaultFontSize: defaultFontSize ?? this.defaultFontSize,
        defaultTheme: defaultTheme ?? this.defaultTheme,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        autoDownloadEpub: autoDownloadEpub ?? this.autoDownloadEpub,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._ref)
      : super(
          AppSettings(
            defaultFontSize: _ref.read(storageServiceProvider).readerFontSize,
            defaultTheme: _ref.read(storageServiceProvider).readerTheme,
            notificationsEnabled:
                _ref.read(storageServiceProvider).notificationsEnabled,
            autoDownloadEpub: _ref.read(storageServiceProvider).autoDownloadEpub,
          ),
        );

  final Ref _ref;

  /// Order used by the "Default Theme" row (RN).
  static const List<String> themeCycle = ['light', 'dark', 'sepia'];

  void setFontSize(double v) {
    final size = v.clamp(12.0, 28.0).toDouble();
    state = state.copyWith(defaultFontSize: size);
    unawaited(_ref.read(storageServiceProvider).setReaderFontSize(size));
  }

  void cycleTheme() {
    final i = themeCycle.indexOf(state.defaultTheme);
    final next = themeCycle[(i + 1) % themeCycle.length];
    state = state.copyWith(defaultTheme: next);
    unawaited(_ref.read(storageServiceProvider).setReaderTheme(next));
  }

  void setNotifications(bool v) {
    state = state.copyWith(notificationsEnabled: v);
    unawaited(_ref.read(storageServiceProvider).setNotificationsEnabled(v));
  }

  void setAutoDownload(bool v) {
    state = state.copyWith(autoDownloadEpub: v);
    unawaited(_ref.read(storageServiceProvider).setAutoDownloadEpub(v));
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(ref),
);
