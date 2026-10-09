import 'dart:convert';

import '../library/data/models/book.dart';

/// Where a book is in the user's reading life.
enum ReadStatus { none, want, reading, finished }

String statusLabel(ReadStatus s) => switch (s) {
      ReadStatus.none => 'Not started',
      ReadStatus.want => 'Want to read',
      ReadStatus.reading => 'Reading',
      ReadStatus.finished => 'Finished',
    };

class Shelf {
  const Shelf({required this.id, required this.name, this.bookIds = const {}});

  final String id;
  final String name;
  final Set<String> bookIds;

  Shelf copyWith({String? name, Set<String>? bookIds}) =>
      Shelf(id: id, name: name ?? this.name, bookIds: bookIds ?? this.bookIds);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'books': bookIds.toList()};

  factory Shelf.fromJson(Map<String, dynamic> j) => Shelf(
        id: '${j['id']}',
        name: '${j['name']}',
        bookIds: {for (final b in (j['books'] as List? ?? const [])) '$b'},
      );
}

/// Everything the user chose themselves: explicit statuses, finish dates,
/// custom shelves and the yearly goal. Kept on the phone (works offline).
class ShelfData {
  const ShelfData({
    this.status = const {},
    this.finishedAt = const {},
    this.shelves = const [],
    this.yearlyGoal = 12,
  });

  final Map<String, ReadStatus> status;
  final Map<String, DateTime> finishedAt;
  final List<Shelf> shelves;
  final int yearlyGoal;

  ShelfData copyWith({
    Map<String, ReadStatus>? status,
    Map<String, DateTime>? finishedAt,
    List<Shelf>? shelves,
    int? yearlyGoal,
  }) =>
      ShelfData(
        status: status ?? this.status,
        finishedAt: finishedAt ?? this.finishedAt,
        shelves: shelves ?? this.shelves,
        yearlyGoal: yearlyGoal ?? this.yearlyGoal,
      );

  String encode() => jsonEncode({
        'status': {for (final e in status.entries) e.key: e.value.name},
        'finishedAt': {for (final e in finishedAt.entries) e.key: e.value.toIso8601String()},
        'shelves': shelves.map((s) => s.toJson()).toList(),
        'yearlyGoal': yearlyGoal,
      });

  static ShelfData decode(String? raw) {
    if (raw == null || raw.isEmpty) return const ShelfData();
    try {
      final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return ShelfData(
        status: {
          for (final e in Map<String, dynamic>.from(j['status'] as Map? ?? const {}).entries)
            e.key: ReadStatus.values.firstWhere((s) => s.name == e.value, orElse: () => ReadStatus.none),
        },
        finishedAt: {
          for (final e in Map<String, dynamic>.from(j['finishedAt'] as Map? ?? const {}).entries)
            if (DateTime.tryParse('${e.value}') != null) e.key: DateTime.parse('${e.value}'),
        },
        shelves: [
          for (final s in (j['shelves'] as List? ?? const []))
            Shelf.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
        yearlyGoal: (j['yearlyGoal'] as num?)?.toInt() ?? 12,
      );
    } catch (_) {
      return const ShelfData();
    }
  }
}

/// The status shown for [b]: the user's explicit choice, otherwise derived from
/// reading progress (completed → Finished, started → Reading).
ReadStatus effectiveStatus(Book b, ShelfData d) {
  final explicit = d.status[b.id];
  if (explicit != null && explicit != ReadStatus.none) return explicit;
  final p = b.progress;
  if (p != null && p.isCompleted) return ReadStatus.finished;
  if (p != null && p.percentage > 0) return ReadStatus.reading;
  return ReadStatus.none;
}

/// When [b] was finished (explicit date → last read → null).
DateTime? finishedDate(Book b, ShelfData d) {
  if (effectiveStatus(b, d) != ReadStatus.finished) return null;
  return d.finishedAt[b.id] ?? b.progress?.lastReadAt ?? b.updatedAt;
}

int finishedInYear(List<Book> books, ShelfData d, int year) =>
    books.where((b) => finishedDate(b, d)?.year == year).length;

/// Pace message for the challenge card ("2 books ahead", "On track", "1 behind").
String challengePace({required int goal, required int finished, required DateTime now}) {
  if (goal <= 0) return '';
  if (finished >= goal) return 'Goal complete! 🎉';
  final start = DateTime(now.year, 1, 1);
  final end = DateTime(now.year + 1, 1, 1);
  final elapsed = now.difference(start).inHours / end.difference(start).inHours;
  final expected = (goal * elapsed).floor();
  final diff = finished - expected;
  if (diff > 0) return '$diff ${diff == 1 ? 'book' : 'books'} ahead of schedule';
  if (diff == 0) return 'Right on track';
  return '${-diff} ${-diff == 1 ? 'book' : 'books'} behind schedule';
}
