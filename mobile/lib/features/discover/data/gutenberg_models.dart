/// Gutendex (https://gutendex.com) models. Parsing is tolerant: every field
/// may be missing / null.
class GutenbergAuthor {
  const GutenbergAuthor({required this.name, this.birthYear, this.deathYear});

  /// "Last, First" as sent by Gutendex.
  final String name;
  final int? birthYear;
  final int? deathYear;

  factory GutenbergAuthor.fromJson(Map<String, dynamic> j) => GutenbergAuthor(
        name: (j['name'] ?? '').toString(),
        birthYear: j['birth_year'] is int ? j['birth_year'] as int : null,
        deathYear: j['death_year'] is int ? j['death_year'] as int : null,
      );
}

class GutenbergBook {
  const GutenbergBook({
    required this.id,
    required this.title,
    required this.authors,
    required this.subjects,
    required this.bookshelves,
    required this.languages,
    required this.formats,
    required this.downloadCount,
  });

  final int id;
  final String title;
  final List<GutenbergAuthor> authors;
  final List<String> subjects;
  final List<String> bookshelves;
  final List<String> languages;
  final Map<String, String> formats;
  final int downloadCount;

  factory GutenbergBook.fromJson(Map<String, dynamic> j) {
    List<String> strings(dynamic v) => v is List
        ? v.where((e) => e != null).map((e) => e.toString()).toList()
        : <String>[];

    final fm = <String, String>{};
    final raw = j['formats'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k != null && v != null) fm[k.toString()] = v.toString();
      });
    }

    final authors = j['authors'];
    final dc = j['download_count'];
    return GutenbergBook(
      id: j['id'] is num ? (j['id'] as num).toInt() : int.tryParse('${j['id']}') ?? 0,
      title: (j['title'] ?? '').toString(),
      authors: authors is List
          ? authors
              .whereType<Map>()
              .map((a) => GutenbergAuthor.fromJson(Map<String, dynamic>.from(a)))
              .toList()
          : <GutenbergAuthor>[],
      subjects: strings(j['subjects']),
      bookshelves: strings(j['bookshelves']),
      languages: strings(j['languages']),
      formats: fm,
      downloadCount: dc is num ? dc.toInt() : 0,
    );
  }
}

class GutenbergPage {
  const GutenbergPage({
    required this.count,
    required this.hasNext,
    required this.results,
  });

  final int count;
  final bool hasNext;
  final List<GutenbergBook> results;

  factory GutenbergPage.fromJson(Map<String, dynamic> j) {
    final res = j['results'];
    return GutenbergPage(
      count: j['count'] is num ? (j['count'] as num).toInt() : 0,
      hasNext: j['next'] != null,
      results: res is List
          ? res
              .whereType<Map>()
              .map((e) => GutenbergBook.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <GutenbergBook>[],
    );
  }
}

// ── helpers (RN `services/gutendex.ts`) ──────────────────────────────────────

/// "Austen, Jane" → "Jane Austen"; anything else is returned unchanged.
String formatAuthorName(String name) {
  final parts = name.split(',').map((s) => s.trim()).toList();
  if (parts.length == 2) return '${parts[1]} ${parts[0]}';
  return name;
}

/// Best EPUB URL (`application/epub+zip`, else `application/epub`), or null.
String? epubUrl(Map<String, String> formats) {
  final u = formats['application/epub+zip'] ?? formats['application/epub'];
  return (u == null || u.isEmpty) ? null : u;
}

/// `image/jpeg`, else the Gutenberg cache cover for [id].
String coverUrl(Map<String, String> formats, int id) {
  final u = formats['image/jpeg'];
  if (u != null && u.isNotEmpty) return u;
  return 'https://www.gutenberg.org/cache/epub/$id/pg$id.cover.medium.jpg';
}

/// Up to [max] authors as "First Last", comma-joined.
String authorsLine(GutenbergBook b, {int? max}) {
  final names = b.authors.map((a) => formatAuthorName(a.name));
  return (max == null ? names : names.take(max)).join(', ');
}

/// RN `(download_count / 1000).toFixed(0)` + "k".
String downloadsK(int downloadCount) =>
    '${(downloadCount / 1000).toStringAsFixed(0)}k';

/// Curated categories shown on Discover (RN `CATEGORIES`).
class DiscoverCategory {
  const DiscoverCategory(this.id, this.label, this.icon);
  final String id;
  final String label;
  final String icon;
}

const List<DiscoverCategory> kDiscoverCategories = [
  DiscoverCategory('adventure', 'Adventure', '🗺️'),
  DiscoverCategory('fiction', 'Fiction', '📖'),
  DiscoverCategory('mystery', 'Mystery', '🔍'),
  DiscoverCategory('romance', 'Romance', '💌'),
  DiscoverCategory('horror', 'Horror', '🎃'),
  DiscoverCategory('philosophy', 'Philosophy', '🧠'),
  DiscoverCategory('science', 'Science', '🔬'),
  DiscoverCategory('history', 'History', '🏛️'),
];

/// RN `handleListen` text for the "Listen Preview" (TTS) of a Gutenberg book.
String listenPreviewText(GutenbergBook b) {
  final first = b.authors.isNotEmpty ? formatAuthorName(b.authors.first.name) : 'Unknown';
  if (b.subjects.isNotEmpty) {
    return '${b.title} by $first. ${b.subjects.join('. ')}.';
  }
  return '${b.title}. By $first. Published by Project Gutenberg.';
}
