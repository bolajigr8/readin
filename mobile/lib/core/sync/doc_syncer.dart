import 'dart:async';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_result.dart';
import '../services/storage_service.dart';

/// Keeps ONE small JSON document (habits, shelves…) in step with the server:
///
///  * the phone stays the source of truth while offline (nothing ever blocks);
///  * changes are pushed a few seconds after the last edit;
///  * the server version makes writes safe — if another phone wrote first the
///    two copies are MERGED (never overwritten) and pushed again;
///  * data is never lost: a failed push simply retries on the next change/launch.
class DocSyncer {
  DocSyncer({
    required this.api,
    required this.storage,
    required this.key,
    required this.readLocal,
    required this.isLocalEmpty,
    required this.applyRemote,
    required this.merge,
    required this.enabled,
    this.debounce = const Duration(seconds: 20),
  });

  final ApiClient api;
  final StorageService storage;
  final String key;

  /// The current local JSON string.
  final String Function() readLocal;
  final bool Function() isLocalEmpty;

  /// Replaces local state by [json] (already merged).
  final void Function(String json) applyRemote;

  /// Union of the local and server copies.
  final String Function(String local, String server) merge;

  /// Sync is allowed (signed in; for gated features: access granted).
  final bool Function() enabled;
  final Duration debounce;

  Timer? _timer;
  bool _busy = false;

  String get _versionKey => '@readin/sync_v_$key';
  String get _dirtyKey => '@readin/sync_dirty_$key';

  /// Local edits not yet confirmed by the server.
  bool get dirty => storage.readInt(_dirtyKey) == 1;
  int get version => storage.readInt(_versionKey);
  Future<void> _setVersion(int v) => storage.writeInt(_versionKey, v);

  void dispose() => _timer?.cancel();

  /// Call after every local change.
  void markChanged() {
    if (!enabled()) return;
    unawaited(storage.writeInt(_dirtyKey, 1));
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(push()));
  }

  Future<ApiResult<_Doc>> _get() => api.get<_Doc>(
        ApiEndpoints.sync(key),
        parser: (d) {
          final m = Map<String, dynamic>.from(d as Map);
          return _Doc(m['data'] as String?, (m['version'] as num?)?.toInt() ?? 0);
        },
      );

  /// Download + merge (call at start and when access is granted).
  Future<void> pull({int depth = 0}) async {
    if (!enabled() || _busy || depth > 2) return;
    _busy = true;
    try {
      // Edits made offline are uploaded FIRST (the phone's newer state wins), so
      // e.g. something deleted offline is not resurrected by the server copy.
      if (dirty) {
        await _putLocked(readLocal(), version, depth);
        return; // (still dirty = offline / locked: tried again next time)
      }

      final res = await _get();
      final doc = res.dataOrNull;
      if (doc == null) return; // offline / locked / old server: keep local data

      final local = readLocal();
      if (doc.data == null) {
        // First time on this account: upload what the phone has.
        if (!isLocalEmpty()) await _putLocked(local, 0, depth);
        return;
      }
      final merged = isLocalEmpty() ? doc.data! : merge(local, doc.data!);
      if (merged != local) applyRemote(merged);
      await _setVersion(doc.version);
      if (merged != doc.data) await _putLocked(merged, doc.version, depth);
    } finally {
      _busy = false;
    }
  }

  /// Upload now (also called after the debounce).
  Future<void> push() async {
    if (!enabled() || _busy) return;
    _busy = true;
    try {
      await _putLocked(readLocal(), version, 0);
    } finally {
      _busy = false;
    }
  }

  Future<void> _putLocked(String data, int base, int depth) async {
    final res = await api.put<int>(
      ApiEndpoints.sync(key),
      data: {'data': data, 'baseVersion': base},
      parser: (d) => ((d as Map)['version'] as num?)?.toInt() ?? base + 1,
    );
    final v = res.dataOrNull;
    if (v != null) {
      await _setVersion(v);
      await storage.writeInt(_dirtyKey, 0);
      return;
    }
    if (res.exceptionOrNull?.statusCode == 409 && depth < 2) {
      // Someone else wrote first: fetch their copy, merge, try again.
      final latest = (await _get()).dataOrNull;
      if (latest == null) return;
      final merged = latest.data == null ? data : merge(data, latest.data!);
      if (merged != data) applyRemote(merged);
      await _putLocked(merged, latest.version, depth + 1);
    }
    // other failures (offline, 403 locked…): keep the local copy, retry later
  }
}

class _Doc {
  const _Doc(this.data, this.version);
  final String? data;
  final int version;
}
