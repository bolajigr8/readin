import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Locally stored details of a book (the server only knows title/author).
class BookMeta {
  const BookMeta({this.title, this.author, this.description = '', this.language = ''});

  /// User edits (null = keep the server's value).
  final String? title;
  final String? author;
  final String description;
  final String language;

  BookMeta copyWith({String? title, String? author, String? description, String? language}) => BookMeta(
        title: title ?? this.title,
        author: author ?? this.author,
        description: description ?? this.description,
        language: language ?? this.language,
      );

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (author != null) 'author': author,
        'description': description,
        'language': language,
      };

  factory BookMeta.fromJson(Map<String, dynamic> j) => BookMeta(
        title: j['title'] as String?,
        author: j['author'] as String?,
        description: (j['description'] ?? '') as String,
        language: (j['language'] ?? '') as String,
      );
}

/// Metadata + cover images kept on the phone: `book_meta.json` and
/// `covers/<bookId>.img`. Works offline.
class BookMetaStore {
  BookMetaStore({Future<Directory> Function()? documentsDir})
      : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDir;
  Map<String, BookMeta>? _cache;

  Future<File> _metaFile() async =>
      File('${(await _documentsDir()).path}${Platform.pathSeparator}book_meta.json');

  Future<Directory> _coversDir() async {
    final d = Directory('${(await _documentsDir()).path}${Platform.pathSeparator}covers');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<Map<String, BookMeta>> _all() async {
    if (_cache != null) return _cache!;
    final out = <String, BookMeta>{};
    try {
      final f = await _metaFile();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString());
        if (j is Map) {
          j.forEach((k, v) {
            if (v is Map) out['$k'] = BookMeta.fromJson(Map<String, dynamic>.from(v));
          });
        }
      }
    } catch (_) {
      // unreadable file = no metadata
    }
    return _cache = out;
  }

  Future<void> _save() async {
    try {
      final f = await _metaFile();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(
        jsonEncode({for (final e in (_cache ?? {}).entries) e.key: e.value.toJson()}),
        flush: true,
      );
      await tmp.rename(f.path);
    } catch (_) {}
  }

  Future<BookMeta?> read(String bookId) async => (await _all())[bookId];

  Future<void> write(String bookId, BookMeta meta) async {
    (await _all())[bookId] = meta;
    await _save();
  }

  Future<File?> coverFile(String bookId) async {
    final f = File('${(await _coversDir()).path}${Platform.pathSeparator}$bookId.img');
    return await f.exists() ? f : null;
  }

  Future<void> saveCover(String bookId, Uint8List bytes) async {
    final f = File('${(await _coversDir()).path}${Platform.pathSeparator}$bookId.img');
    await f.writeAsBytes(bytes, flush: true);
  }

  /// When a pending book gets its server id.
  Future<void> rename(String oldId, String newId) async {
    final all = await _all();
    final m = all.remove(oldId);
    if (m != null) {
      all[newId] = m;
      await _save();
    }
    final c = await coverFile(oldId);
    if (c != null) {
      try {
        await c.rename('${c.parent.path}${Platform.pathSeparator}$newId.img');
      } on FileSystemException {
        // keep old name
      }
    }
  }

  Future<void> delete(String bookId) async {
    final all = await _all();
    if (all.remove(bookId) != null) await _save();
    final c = await coverFile(bookId);
    try {
      await c?.delete();
    } on FileSystemException {
      // ignore
    }
  }
}
