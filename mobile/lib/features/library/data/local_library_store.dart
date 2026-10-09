import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models/book.dart';

/// Offline-first persistence for the library:
///
/// * **cache** — the last library the server sent (shown instantly on launch,
///   even when the server is asleep / the phone is offline);
/// * **pending** — books imported on this phone that the server does not know
///   yet (offline import / old server). They are registered automatically later.
///
/// Plain JSON files in the app documents folder, one pair per user.
class LocalLibraryStore {
  LocalLibraryStore({Future<Directory> Function()? documentsDir})
      : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDir;

  Future<File> _file(String name) async {
    final dir = await _documentsDir();
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  static String _safe(String userId) => userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  Future<Object?> _readJson(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString());
    } catch (_) {
      return null; // corrupt cache = no cache
    }
  }

  Future<void> _writeJson(String name, Object data) async {
    try {
      final f = await _file(name);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(data), flush: true);
      await tmp.rename(f.path);
    } catch (_) {
      // cache is best effort
    }
  }

  // ── server cache ────────────────────────────────────────────────────────────

  Future<LibraryResponse?> readCache(String userId) async {
    final j = await _readJson('library_cache_${_safe(userId)}.json');
    if (j is! Map) return null;
    return LibraryResponse.fromJson(Map<String, dynamic>.from(j));
  }

  Future<void> writeCache(String userId, LibraryResponse r) =>
      _writeJson('library_cache_${_safe(userId)}.json', r.toJson());

  // ── pending (not yet on the server) ─────────────────────────────────────────

  Future<List<Book>> readPending(String userId) async {
    final j = await _readJson('library_pending_${_safe(userId)}.json');
    if (j is! List) return <Book>[];
    return j
        .whereType<Map>()
        .map((e) => Book.fromJson(Map<String, dynamic>.from(e)).copyWith(pendingSync: true))
        .toList();
  }

  Future<void> writePending(String userId, List<Book> books) =>
      _writeJson('library_pending_${_safe(userId)}.json', books.map((b) => b.toJson()).toList());

  Future<void> addPending(String userId, Book book) async {
    final list = await readPending(userId);
    list.removeWhere((b) => b.id == book.id);
    list.insert(0, book);
    await writePending(userId, list);
  }

  Future<void> removePending(String userId, String bookId) async {
    final list = await readPending(userId);
    list.removeWhere((b) => b.id == bookId);
    await writePending(userId, list);
  }
}
