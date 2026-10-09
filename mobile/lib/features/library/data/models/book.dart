/// Reading progress joined onto a book by `GET /library`.
class BookProgress {
  const BookProgress({
    required this.percentage,
    required this.lastReadAt,
    required this.isCompleted,
  });

  /// 0–100.
  final double percentage;
  final DateTime? lastReadAt;
  final bool isCompleted;

  factory BookProgress.fromJson(Map<String, dynamic> json) => BookProgress(
        percentage: _num(json['percentage']).toDouble(),
        lastReadAt: _date(json['lastReadAt']),
        isCompleted: json['isCompleted'] == true,
      );
}

import '../../../../core/formats.dart';

/// A book in the user's library (API_CONTRACT `Book`). Parsing is tolerant:
/// missing strings become `''`, missing numbers `0`, missing dates the epoch.
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverUrl,
    required this.originalFileUrl,
    required this.convertedFileUrl,
    required this.originalFormat,
    required this.fileSize,
    required this.status,
    required this.source,
    required this.gutenbergId,
    required this.language,
    required this.genre,
    required this.createdAt,
    required this.updatedAt,
    required this.progress,
    this.fingerprint = '',
    this.pendingSync = false,
  });

  final String id;
  final String title;
  final String author;
  final String description;
  final String coverUrl;
  final String originalFileUrl;
  final String convertedFileUrl;

  /// As sent by the server ('' on servers that do not select the field).
  final String originalFormat;
  final int fileSize;
  final String status;

  /// `'upload'` or `'discover'`.
  final String source;
  final String? gutenbergId;
  final String language;
  final String genre;
  final DateTime createdAt;
  final DateTime updatedAt;
  final BookProgress? progress;

  /// Content fingerprint of the file (local-first books; '' for others).
  final String fingerprint;

  /// Imported on this phone but not yet registered on the server.
  final bool pendingSync;

  /// The file the reader opens (`convertedFileUrl`; equals the original for
  /// uploads). Falls back to the original URL.
  String get readableUrl =>
      convertedFileUrl.isNotEmpty ? convertedFileUrl : originalFileUrl;

  /// `'pdf'` or `'epub'` (or the raw value / `''` if unknown):
  /// `originalFormat`, else the extension of [readableUrl].
  String get format {
    final f = originalFormat.toLowerCase();
    if (formatForExtension(f) != null) return f;
    final path = (Uri.tryParse(readableUrl)?.path ?? '').toLowerCase();
    final fromUrl = extensionOfName(path);
    if (formatForExtension(fromUrl) != null) return fromUrl;
    return f;
  }

  /// How this book is opened (full reader, document viewer, comic, other app).
  ViewerKind get kind => kindOfFormat(format);

  /// Imported from this phone (the file lives on the device, not in the cloud).
  bool get isLocalFirst => source == 'local' || id.startsWith('local_');

  bool get isPdf => format == 'pdf';
  bool get isReady => status == 'ready';
  bool get hasCover => coverUrl.isNotEmpty;
  double get percentage => progress?.percentage ?? 0;

  Book copyWith({BookProgress? progress, bool? pendingSync, String? fingerprint}) => Book(
        id: id,
        title: title,
        author: author,
        description: description,
        coverUrl: coverUrl,
        originalFileUrl: originalFileUrl,
        convertedFileUrl: convertedFileUrl,
        originalFormat: originalFormat,
        fileSize: fileSize,
        status: status,
        source: source,
        gutenbergId: gutenbergId,
        language: language,
        genre: genre,
        createdAt: createdAt,
        updatedAt: updatedAt,
        progress: progress ?? this.progress,
        fingerprint: fingerprint ?? this.fingerprint,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'title': title,
        'author': author,
        'description': description,
        'coverUrl': coverUrl,
        'originalFileUrl': originalFileUrl,
        'convertedFileUrl': convertedFileUrl,
        'originalFormat': originalFormat,
        'fileSize': fileSize,
        'status': status,
        'source': source,
        'gutenbergId': gutenbergId,
        'language': language,
        'genre': genre,
        'fingerprint': fingerprint,
        'pendingSync': pendingSync,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (progress != null)
          'progress': {
            'percentage': progress!.percentage,
            'lastReadAt': progress!.lastReadAt?.toIso8601String(),
            'isCompleted': progress!.isCompleted,
          },
      };

  factory Book.fromJson(Map<String, dynamic> json) {
    final p = json['progress'];
    final gid = json['gutenbergId'];
    return Book(
      id: _str(json['_id'] ?? json['id']),
      title: _str(json['title']),
      author: _str(json['author']),
      description: _str(json['description']),
      coverUrl: _str(json['coverUrl']),
      originalFileUrl: _str(json['originalFileUrl']),
      convertedFileUrl: _str(json['convertedFileUrl']),
      originalFormat: _str(json['originalFormat']),
      fileSize: _num(json['fileSize']).toInt(),
      status: _str(json['status']),
      source: _str(json['source']),
      gutenbergId: gid == null || gid.toString().isEmpty ? null : gid.toString(),
      language: _str(json['language']),
      genre: _str(json['genre']),
      createdAt: _date(json['createdAt']) ?? _epoch,
      updatedAt: _date(json['updatedAt']) ?? _epoch,
      progress: p is Map
          ? BookProgress.fromJson(Map<String, dynamic>.from(p))
          : null,
      fingerprint: _str(json['fingerprint']),
      pendingSync: json['pendingSync'] == true,
    );
  }
}

class LibraryMeta {
  const LibraryMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.limitReached,
  });

  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool limitReached;

  static const LibraryMeta empty = LibraryMeta(
    total: 0,
    page: 1,
    limit: 50,
    totalPages: 0,
    limitReached: false,
  );

  Map<String, dynamic> toJson() => {
        'total': total,
        'page': page,
        'limit': limit,
        'totalPages': totalPages,
        'limitReached': limitReached,
      };

  factory LibraryMeta.fromJson(Map<String, dynamic> json) => LibraryMeta(
        total: _num(json['total']).toInt(),
        page: _num(json['page']).toInt(),
        limit: _num(json['limit']).toInt(),
        totalPages: _num(json['totalPages']).toInt(),
        limitReached: json['limitReached'] == true,
      );
}

class LibraryResponse {
  const LibraryResponse({required this.books, required this.meta});

  final List<Book> books;
  final LibraryMeta meta;

  static const LibraryResponse empty =
      LibraryResponse(books: [], meta: LibraryMeta.empty);

  Map<String, dynamic> toJson() => {
        'books': books.map((b) => b.toJson()).toList(),
        'meta': meta.toJson(),
      };

  factory LibraryResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['books'];
    final meta = json['meta'];
    return LibraryResponse(
      books: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Book.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <Book>[],
      meta: meta is Map
          ? LibraryMeta.fromJson(Map<String, dynamic>.from(meta))
          : LibraryMeta.empty,
    );
  }
}

/// `GET /library/:id` → `{book, progress, annotationCount}`.
class BookDetail {
  const BookDetail({
    required this.book,
    required this.progress,
    required this.annotationCount,
  });

  final Book book;
  final BookProgress? progress;
  final int annotationCount;

  factory BookDetail.fromJson(Map<String, dynamic> json) {
    final p = json['progress'];
    final progress = p is Map
        ? BookProgress.fromJson(Map<String, dynamic>.from(p))
        : null;
    return BookDetail(
      book: Book.fromJson(Map<String, dynamic>.from(json['book'] as Map))
          .copyWith(progress: progress),
      progress: progress,
      annotationCount: _num(json['annotationCount']).toInt(),
    );
  }
}

// ── tolerant helpers ─────────────────────────────────────────────────────────
final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

String _str(dynamic v) => v == null ? '' : v.toString();

num _num(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
