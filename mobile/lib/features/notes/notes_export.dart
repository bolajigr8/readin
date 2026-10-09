import 'package:intl/intl.dart';

import '../annotations/data/annotation_models.dart';

/// All highlights / notes of one book (for the notes screen and export).
class NoteGroup {
  const NoteGroup({
    required this.bookId,
    required this.title,
    required this.author,
    required this.items,
  });

  final String bookId;
  final String title;
  final String author;
  final List<Annotation> items;
}

String _date(DateTime d) => DateFormat.yMMMd().format(d);

String _meta(Annotation a) {
  final parts = <String>[
    if (a.chapterTitle.trim().isNotEmpty) a.chapterTitle.trim(),
    _date(a.createdAt),
  ];
  return parts.join(' · ');
}

/// Markdown export (works in Obsidian, Notion, Bear, GitHub…).
String exportMarkdown(List<NoteGroup> groups) {
  final b = StringBuffer();
  for (final g in groups) {
    if (g.items.isEmpty) continue;
    b.writeln('# ${g.title}');
    if (g.author.trim().isNotEmpty) b.writeln('*${g.author.trim()}*');
    b.writeln();
    for (final a in g.items) {
      for (final line in a.selectedText.trim().split('\n')) {
        b.writeln('> $line');
      }
      b.writeln();
      if (a.hasNote) {
        b.writeln('**Note:** ${a.note.trim()}');
        b.writeln();
      }
      b.writeln('_${_meta(a)}_');
      b.writeln();
    }
    b.writeln('---');
    b.writeln();
  }
  return b.toString().trimRight();
}

/// Plain-text export.
String exportText(List<NoteGroup> groups) {
  final b = StringBuffer();
  for (final g in groups) {
    if (g.items.isEmpty) continue;
    b.writeln(g.title.toUpperCase());
    if (g.author.trim().isNotEmpty) b.writeln('by ${g.author.trim()}');
    b.writeln();
    for (var i = 0; i < g.items.length; i++) {
      final a = g.items[i];
      b.writeln('${i + 1}. "${a.selectedText.trim()}"');
      if (a.hasNote) b.writeln('   Note: ${a.note.trim()}');
      b.writeln('   (${_meta(a)})');
      b.writeln();
    }
    b.writeln('----------------------------------------');
    b.writeln();
  }
  return b.toString().trimRight();
}

/// Case-insensitive search over quote, note, chapter and book title.
List<NoteGroup> searchNotes(List<NoteGroup> groups, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return groups;
  final out = <NoteGroup>[];
  for (final g in groups) {
    final titleHit = g.title.toLowerCase().contains(q) || g.author.toLowerCase().contains(q);
    final items = titleHit
        ? g.items
        : g.items
            .where((a) =>
                a.selectedText.toLowerCase().contains(q) ||
                a.note.toLowerCase().contains(q) ||
                a.chapterTitle.toLowerCase().contains(q))
            .toList();
    if (items.isNotEmpty) {
      out.add(NoteGroup(bookId: g.bookId, title: g.title, author: g.author, items: items));
    }
  }
  return out;
}
