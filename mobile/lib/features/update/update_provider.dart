import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_version.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/distribution.dart';
import '../auth/providers/auth_providers.dart';

/// The server's answer to "is there a newer ReadIn?" (`GET /app/version`, S2).
class UpdateInfo {
  const UpdateInfo({
    required this.updateAvailable,
    required this.mandatory,
    this.latestVersion = '',
    this.latestVersionCode = 0,
    this.downloadUrl = '',
    this.sizeBytes = 0,
    this.releaseNotes = const [],
  });

  final bool updateAvailable;
  final bool mandatory;
  final String latestVersion;
  final int latestVersionCode;
  final String downloadUrl;
  final int sizeBytes;
  final List<String> releaseNotes;

  /// "34 MB" ('' when unknown).
  String get sizeText => sizeBytes > 0 ? '${(sizeBytes / 1048576).toStringAsFixed(1)} MB' : '';

  factory UpdateInfo.fromJson(Map<String, dynamic> j) => UpdateInfo(
        updateAvailable: j['updateAvailable'] == true,
        mandatory: j['mandatory'] == true,
        latestVersion: '${j['latestVersion'] ?? ''}',
        latestVersionCode: (j['latestVersionCode'] as num?)?.toInt() ?? 0,
        downloadUrl: '${j['downloadUrl'] ?? ''}',
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
        releaseNotes: [
          for (final n in (j['releaseNotes'] as List? ?? const []))
            if (n is String && n.trim().isNotEmpty) n.trim(),
        ],
      );
}

class UpdateState {
  const UpdateState({this.info, this.dismissedCode = 0});

  /// Fresh answer from the server in THIS app session (null = not asked / unreachable → never block).
  final UpdateInfo? info;

  /// "Later" was pressed for this version code (the banner stays hidden for it).
  final int dismissedCode;

  /// Friendly Home banner (optional update, not dismissed).
  bool get showBanner {
    final i = info;
    return i != null && i.updateAvailable && !i.mandatory && i.downloadUrl.isNotEmpty && i.latestVersionCode != dismissedCode;
  }

  /// Full-screen "please update" (only from a fresh server answer).
  bool get mustUpdate {
    final i = info;
    return i != null && i.updateAvailable && i.mandatory && i.downloadUrl.isNotEmpty;
  }
}

const String _kLastCheck = '@readin/update_last_check';
const String _kDismissed = '@readin/update_dismissed_code';

/// Asks the server at launch and when the app comes back, at most every [minGap] (a mandatory answer is
/// re-checked on every resume so the screen goes away as soon as the admin changes it).
class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier(this._ref, {this.minGap = const Duration(hours: 6), DateTime Function()? clock})
      : _now = clock ?? DateTime.now,
        super(UpdateState(dismissedCode: int.tryParse(_ref.read(storageServiceProvider).readString(_kDismissed) ?? '') ?? 0));

  final Ref _ref;
  final Duration minGap;
  final DateTime Function() _now;
  bool _busy = false;

  Future<void> check({bool force = false}) async {
    if (_busy) return;
    final storage = _ref.read(storageServiceProvider);
    final last = DateTime.tryParse(storage.readString(_kLastCheck) ?? '');
    final now = _now();
    final recently = last != null && now.difference(last) < minGap && now.isAfter(last);
    if (!force && recently && state.info != null && !state.mustUpdate) return;
    _busy = true;
    try {
      final res = await _ref.read(apiClientProvider).get<UpdateInfo>(
            ApiEndpoints.appVersion,
            queryParameters: {
              'channel': _ref.read(distributionProvider).wireName,
              'versionCode': kAppVersionCode,
            },
            parser: (d) => UpdateInfo.fromJson(Map<String, dynamic>.from(d as Map)),
          );
      final info = res.dataOrNull;
      if (info == null || !mounted) return; // unreachable / error → keep whatever we had, never block
      state = UpdateState(info: info, dismissedCode: state.dismissedCode);
      unawaited(storage.writeString(_kLastCheck, now.toIso8601String()));
    } finally {
      _busy = false;
    }
  }

  void later() {
    final code = state.info?.latestVersionCode ?? 0;
    state = UpdateState(info: state.info, dismissedCode: code);
    unawaited(_ref.read(storageServiceProvider).writeString(_kDismissed, '$code'));
  }
}

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) => UpdateNotifier(ref));
