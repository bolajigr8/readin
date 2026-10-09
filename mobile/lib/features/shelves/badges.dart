/// Achievement badges. Pure logic: [evaluateBadges] turns the user's numbers
/// into a list of unlocked / locked badges with progress.
class BadgeInput {
  const BadgeInput({
    this.finishedBooks = 0,
    this.libraryBooks = 0,
    this.streak = 0,
    this.readingSeconds = 0,
    this.annotations = 0,
    this.nightSeconds = 0,
    this.goalDays = 0,
  });

  final int finishedBooks;
  final int libraryBooks;
  final int streak;
  final int readingSeconds;
  final int annotations;
  final int nightSeconds;
  final int goalDays;
}

class BadgeDef {
  const BadgeDef(this.id, this.emoji, this.title, this.description, this.target, this.value);

  final String id;
  final String emoji;
  final String title;
  final String description;
  final int target;
  final int Function(BadgeInput) value;
}

class BadgeStatus {
  const BadgeStatus(this.def, this.current);

  final BadgeDef def;
  final int current;

  bool get unlocked => current >= def.target;
  double get progress => def.target == 0 ? 1 : (current / def.target).clamp(0.0, 1.0).toDouble();
}

final List<BadgeDef> kBadges = [
  BadgeDef('first_book', '📖', 'First Chapter', 'Finish your first book', 1, (i) => i.finishedBooks),
  BadgeDef('books_5', '📚', 'Bookworm', 'Finish 5 books', 5, (i) => i.finishedBooks),
  BadgeDef('books_10', '🏛️', 'Library Legend', 'Finish 10 books', 10, (i) => i.finishedBooks),
  BadgeDef('books_25', '👑', 'Reading Royalty', 'Finish 25 books', 25, (i) => i.finishedBooks),
  BadgeDef('streak_3', '🔥', 'Warming Up', 'Read 3 days in a row', 3, (i) => i.streak),
  BadgeDef('streak_7', '⚡', 'On Fire', 'Read 7 days in a row', 7, (i) => i.streak),
  BadgeDef('streak_30', '🌟', 'Unstoppable', 'Read 30 days in a row', 30, (i) => i.streak),
  BadgeDef('hours_1', '⏱️', 'First Hour', 'Read for 1 hour in total', 3600, (i) => i.readingSeconds),
  BadgeDef('hours_10', '⏳', 'Deep Reader', 'Read for 10 hours in total', 36000, (i) => i.readingSeconds),
  BadgeDef('hours_50', '🧠', 'Marathon Mind', 'Read for 50 hours in total', 180000, (i) => i.readingSeconds),
  BadgeDef('notes_10', '✏️', 'Highlighter', 'Make 10 highlights or notes', 10, (i) => i.annotations),
  BadgeDef('notes_50', '🎓', 'Scholar', 'Make 50 highlights or notes', 50, (i) => i.annotations),
  BadgeDef('collector', '🗂️', 'Collector', 'Have 10 books in your library', 10, (i) => i.libraryBooks),
  BadgeDef('night_owl', '🦉', 'Night Owl', 'Read 10 minutes after 10 pm', 600, (i) => i.nightSeconds),
  BadgeDef('goal_5', '🎯', 'Goal Getter', 'Reach your daily goal 5 times', 5, (i) => i.goalDays),
];

List<BadgeStatus> evaluateBadges(BadgeInput input) =>
    [for (final b in kBadges) BadgeStatus(b, b.value(input))];
