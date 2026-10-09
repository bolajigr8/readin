import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../../../core/api/api_result.dart';
import '../../../core/formats.dart';
import '../../import/data/import_models.dart' show titleFromFileName;
import 'local_library_store.dart';
import 'models/book.dart';
import 'repositories/library_repository.dart';
import 'services/download_service.dart';

enum ImportStatus {
  /// Registered on the server and stored on the phone.
  imported,

  /// Stored on the phone; the server will be told later (offline / old server).
  pending,

  /// The same file is already in the library.
  duplicate,

  /// Free-plan limit reached (server said 403).
  limit,
  unsupported,
  failed,
}

class ImportOutcome {
  const ImportOutcome(this.name, this.status, {this.book, this.message});

  final String name;
  final ImportStatus status;
  final Book? book;
  final String? message;

  bool get ok => status == ImportStatus.imported || status == ImportStatus.pending;
}

/// Content fingerprint: SHA-1 of the first 512 KB + the byte length. Fast for
/// huge files, and identical for identical copies of a file.
Future<String> fingerprintOf(File file) async {
  final len = await file.length();
  final raf = await file.open();
  try {
    final head = await raf.read(math.min(len, 512 * 1024));
    final bytes = <int>[...head, ...utf8.encode('|$len')];
    return sha1.convert(bytes).toString();
  } finally {
    await raf.close();
  }
}

/// Local-first import: the file is copied into the app's storage and a small
/// record is registered on the server (title, format, size, fingerprint).
/// If the server cannot be reached the book is still imported ("pending").
class LocalImportService {
  LocalImportService({
    required DownloadService downloads,
    required LocalLibraryStore store,
    required LibraryRepository repo,
    required String? Function() userId,
  })  : _downloads = downloads,
        _store = store,
        _repo = repo,
        _userId = userId;

  final DownloadService _downloads;
  final LocalLibraryStore _store;
  final LibraryRepository _repo;
  final String? Function() _userId;

  /// Imports one file. [knownFingerprints] = fingerprints already in the library.
  Future<ImportOutcome> importOne(
    String path, {
    Set<String> knownFingerprints = const {},
    String? displayName,
  }) async {
    final name = displayName ?? path.split(RegExp(r'[\\/]')).last;
    final ext = extensionOfName(name);
    final uid = _userId();
    if (uid == null) {
      return ImportOutcome(name, ImportStatus.failed, message: 'Please sign in first.');
    }
    if (formatForExtension(ext) == null) {
      return ImportOutcome(
        name,
        ImportStatus.unsupported,
        message: 'This file type is not supported yet.',
      );
    }

    final file = File(path);
    try {
      if (!await file.exists() || await file.length() == 0) {
        return ImportOutcome(name, ImportStatus.failed, message: 'The file is empty or missing.');
      }
      if (!await DownloadService.hasValidMagicBytes(file, ext)) {
        return ImportOutcome(
          name,
          ImportStatus.failed,
          message: 'This file does not look like a valid ${ext.toUpperCase()}. It may be corrupted.',
        );
      }

      final fp = await fingerprintOf(file);
      if (knownFingerprints.contains(fp)) {
        return ImportOutcome(name, ImportStatus.duplicate, message: 'Already in your library.');
      }

      final size = await file.length();
      final title = titleFromFileName(name);

      // 1) Tell the server (best effort).
      final res = await _repo.registerLocal({
        'title': title,
        'author': '',
        'format': ext,
        'fileSize': size,
        'fingerprint': fp,
      });

      Book book;
      var status = ImportStatus.imported;
      final data = res.dataOrNull;
      if (data != null) {
        book = data.book.fingerprint.isEmpty ? data.book.copyWith(fingerprint: fp) : data.book;
        if (data.deduped) status = ImportStatus.duplicate;
      } else {
        final err = res.exceptionOrNull;
        if (err?.statusCode == 403) {
          return ImportOutcome(name, ImportStatus.limit, message: err!.message);
        }
        // Offline, server asleep, old server (404) … keep it on the phone.
        final now = DateTime.now();
        book = Book(
          id: 'local_$fp',
          title: title,
          author: '',
          description: '',
          coverUrl: '',
          originalFileUrl: '',
          convertedFileUrl: '',
          originalFormat: ext,
          fileSize: size,
          status: 'ready',
          source: 'local',
          gutenbergId: null,
          language: 'en',
          genre: '',
          createdAt: now,
          updatedAt: now,
          progress: null,
          fingerprint: fp,
          pendingSync: true,
        );
        status = ImportStatus.pending;
      }

      // 2) Store the file next to the app's other books: books/<id>.<ext>
      await _downloads.importLocalCopy(bookId: book.id, source: file, format: ext);
      if (status == ImportStatus.pending) await _store.addPending(uid, book);

      // A duplicate answered by the server still needs the file on THIS phone
      // (second device): that is exactly what the copy above did.
      return ImportOutcome(name, status, book: book);
    } on Object catch (e) {
      return ImportOutcome(name, ImportStatus.failed, message: _clean(e));
    }
  }

  /// Imports many files one after another ([onProgress] gets done/total).
  Future<List<ImportOutcome>> importMany(
    List<String> paths, {
    Set<String> knownFingerprints = const {},
    void Function(int done, int total)? onProgress,
  }) async {
    final known = {...knownFingerprints};
    final out = <ImportOutcome>[];
    for (var i = 0; i < paths.length; i++) {
      final o = await importOne(paths[i], knownFingerprints: known);
      final fp = o.book?.fingerprint ?? '';
      if (fp.isNotEmpty) known.add(fp);
      out.add(o);
      onProgress?.call(i + 1, paths.length);
    }
    return out;
  }

  /// Registers every pending book on the server. Returns how many were synced.
  Future<int> syncPending() async {
    final uid = _userId();
    if (uid == null) return 0;
    final pending = await _store.readPending(uid);
    var synced = 0;
    for (final b in pending) {
      final res = await _repo.registerLocal({
        'title': b.title,
        'author': b.author,
        'format': b.originalFormat,
        'fileSize': b.fileSize,
        'fingerprint': b.fingerprint,
      });
      final data = res.dataOrNull;
      if (data == null) {
        // Still offline / old server: try again next time. A 403 (limit) also
        // stays pending so nothing is lost.
        if (res.exceptionOrNull?.statusCode == null) break; // no network → stop early
        continue;
      }
      // Move the file to its permanent (server) id.
      final old = await _downloads.localFile(b.id, b.format);
      if (old != null) {
        try {
          final dest = await _downloads.localPath(data.book.id, b.format);
          await old.rename(dest);
        } on FileSystemException {
          // keep the old name; the book still opens through the pending record
        }
      }
      await _store.removePending(uid, b.id);
      synced++;
    }
    return synced;
  }

  static String _clean(Object e) {
    final s = e.toString();
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }
}
