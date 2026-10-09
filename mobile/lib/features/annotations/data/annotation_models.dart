import 'package:flutter/painting.dart';

import '../../../constants/app_colors.dart';

enum HighlightColor {
  yellow('Yellow', AppColors.highlightYellow),
  green('Green', AppColors.highlightGreen),
  blue('Blue', AppColors.highlightBlue),
  pink('Pink', AppColors.highlightPink),
  purple('Purple', AppColors.highlightPurple);

  const HighlightColor(this.label, this.color);
  final String label;
  final Color color;

  /// `#RRGGBB` for the epub.js highlight (`fill`).
  String get hex =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static HighlightColor parse(dynamic v) {
    final s = (v ?? '').toString();
    for (final c in HighlightColor.values) {
      if (c.name == s) return c;
    }
    return HighlightColor.yellow;
  }
}

DateTime _date(dynamic v) =>
    DateTime.tryParse('${v ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

String _str(dynamic v) => v == null ? '' : v.toString();

int _int(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

/// Server `Annotation` (highlight or note).
class Annotation {
  const Annotation({
    required this.id,
    required this.bookId,
    required this.type,
    required this.cfiRange,
    required this.selectedText,
    required this.note,
    required this.color,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.createdAt,
  });

  final String id;
  final String bookId;

  /// `'highlight'` | `'note'`.
  final String type;
  final String cfiRange;
  final String selectedText;
  final String note;
  final HighlightColor color;
  final String chapterTitle;
  final int chapterIndex;
  final DateTime createdAt;

  bool get hasNote => note.trim().isNotEmpty;

  Annotation copyWith({String? note, HighlightColor? color}) => Annotation(
        id: id,
        bookId: bookId,
        type: type,
        cfiRange: cfiRange,
        selectedText: selectedText,
        note: note ?? this.note,
        color: color ?? this.color,
        chapterTitle: chapterTitle,
        chapterIndex: chapterIndex,
        createdAt: createdAt,
      );

  factory Annotation.fromJson(Map<String, dynamic> j) => Annotation(
        id: _str(j['_id'] ?? j['id']),
        bookId: _str(j['bookId']),
        type: _str(j['type']).isEmpty ? 'highlight' : _str(j['type']),
        cfiRange: _str(j['cfiRange']),
        selectedText: _str(j['selectedText']),
        note: _str(j['note']),
        color: HighlightColor.parse(j['color']),
        chapterTitle: _str(j['chapterTitle']),
        chapterIndex: _int(j['chapterIndex']),
        createdAt: _date(j['createdAt']),
      );
}

/// Body of `POST /annotations` (server zod schema limits applied here).
class NewAnnotation {
  const NewAnnotation({
    required this.type,
    required this.cfiRange,
    required this.selectedText,
    this.note = '',
    this.color = HighlightColor.yellow,
    this.chapterTitle = '',
    this.chapterIndex = 0,
  });

  final String type;
  final String cfiRange;
  final String selectedText;
  final String note;
  final HighlightColor color;
  final String chapterTitle;
  final int chapterIndex;

  Map<String, dynamic> toJson(String bookId) {
    var text = selectedText;
    if (text.length > 2000) text = text.substring(0, 2000); // server max
    var n = note;
    if (n.length > 5000) n = n.substring(0, 5000); // server max
    return {
      'bookId': bookId,
      'type': type,
      'cfiRange': cfiRange,
      'selectedText': text,
      'note': n,
      'color': color.name,
      'chapterTitle': chapterTitle,
      'chapterIndex': chapterIndex < 0 ? 0 : chapterIndex,
    };
  }
}

/// Server `Bookmark`.
class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.cfi,
    required this.label,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.percentage,
    required this.createdAt,
  });

  final String id;
  final String bookId;
  final String cfi;
  final String label;
  final String chapterTitle;
  final int chapterIndex;
  final double percentage;
  final DateTime createdAt;

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        id: _str(j['_id'] ?? j['id']),
        bookId: _str(j['bookId']),
        cfi: _str(j['cfi']),
        label: _str(j['label']),
        chapterTitle: _str(j['chapterTitle']),
        chapterIndex: _int(j['chapterIndex']),
        percentage: j['percentage'] is num
            ? (j['percentage'] as num).toDouble()
            : double.tryParse('${j['percentage']}') ?? 0,
        createdAt: _date(j['createdAt']),
      );
}

/// Body of `POST /bookmarks`.
class NewBookmark {
  const NewBookmark({
    required this.cfi,
    required this.label,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.percentage,
  });

  final String cfi;
  final String label;
  final String chapterTitle;
  final int chapterIndex;
  final double percentage;

  Map<String, dynamic> toJson(String bookId) => {
        'bookId': bookId,
        'cfi': cfi,
        'label': label.length > 200 ? label.substring(0, 200) : label,
        'chapterTitle': chapterTitle,
        'chapterIndex': chapterIndex < 0 ? 0 : chapterIndex,
        'percentage': percentage.clamp(0.0, 100.0).toDouble(),
      };
}
