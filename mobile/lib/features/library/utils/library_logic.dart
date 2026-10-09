import '../data/models/book.dart';

enum SortKey {
  recent('Recent'),
  title('Title'),
  author('Author'),
  lastRead('Last Read');

  const SortKey(this.label);
  final String label;
}

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// RN `sortBooks` (stable; `localeCompare` ≈ case-insensitive compare).
List<Book> sortBooks(List<Book> books, SortKey sort) {
  final indexed = [for (var i = 0; i < books.length; i++) (i, books[i])];

  int byDateDesc(DateTime a, DateTime b) => b.compareTo(a);
  int ci(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

  indexed.sort((x, y) {
    final a = x.$2;
    final b = y.$2;
    final c = switch (sort) {
      SortKey.title => ci(a.title, b.title),
      SortKey.author => ci(a.author, b.author),
      SortKey.lastRead => byDateDesc(
          a.progress?.lastReadAt ?? _epoch,
          b.progress?.lastReadAt ?? _epoch,
        ),
      SortKey.recent => byDateDesc(a.createdAt, b.createdAt),
    };
    return c != 0 ? c : x.$1.compareTo(y.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// Ready books matching [query] (title or author, case-insensitive).
List<Book> filterBooks(List<Book> books, String query) {
  final ready = books.where((b) => b.status == 'ready');
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return ready.toList();
  return ready
      .where(
        (b) =>
            b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q),
      )
      .toList();
}

/// RN `useContinueReading`: ready, 0 < % < 99, not completed; most recently
/// read first (`lastReadAt ?? updatedAt`); top 3.
List<Book> selectContinueReading(List<Book> books) {
  final list = books.where((b) {
    final p = b.progress;
    return b.status == 'ready' &&
        p != null &&
        p.percentage > 0 &&
        p.percentage < 99 &&
        !p.isCompleted;
  }).toList();

  list.sort((a, b) {
    final at = a.progress?.lastReadAt ?? a.updatedAt;
    final bt = b.progress?.lastReadAt ?? b.updatedAt;
    return bt.compareTo(at);
  });
  return list.take(3).toList();
}
