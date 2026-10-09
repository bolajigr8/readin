/// `GET /progress/stats/me` (patched server).
class ReadingStats {
  const ReadingStats({
    required this.totalBooks,
    required this.completedBooks,
    required this.totalReadingTimeSeconds,
    required this.annotationCount,
    required this.averageCompletionRate,
    required this.currentStreak,
    required this.booksInProgress,
  });

  final int totalBooks;
  final int completedBooks;
  final int totalReadingTimeSeconds;
  final int annotationCount;
  final int averageCompletionRate;
  final int currentStreak;
  final int booksInProgress;

  static const ReadingStats zero = ReadingStats(
    totalBooks: 0,
    completedBooks: 0,
    totalReadingTimeSeconds: 0,
    annotationCount: 0,
    averageCompletionRate: 0,
    currentStreak: 0,
    booksInProgress: 0,
  );

  factory ReadingStats.fromJson(Map<String, dynamic> j) {
    int n(dynamic v) => v is num ? v.round() : (int.tryParse('$v') ?? 0);
    // Old servers send `booksCompleted` only.
    return ReadingStats(
      totalBooks: n(j['totalBooks']),
      completedBooks: n(j['completedBooks'] ?? j['booksCompleted']),
      totalReadingTimeSeconds: n(j['totalReadingTimeSeconds']),
      annotationCount: n(j['annotationCount']),
      averageCompletionRate: n(j['averageCompletionRate']),
      currentStreak: n(j['currentStreak']),
      booksInProgress: n(j['booksInProgress']),
    );
  }
}
