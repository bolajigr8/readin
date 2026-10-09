import 'package:intl/intl.dart';

/// RN `formatFileSize`: 512 → "512 B", 1536 → "1.5 KB", 2097152 → "2.0 MB".
String formatFileSize(int bytes) {
  if (bytes == 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// RN `getGreeting` (<12 morning, <17 afternoon, else evening).
String getGreeting([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// RN `formatDate` → "May 21".
String formatDate(DateTime date) => DateFormat('MMM d').format(date);

/// Profile "Read Time" (RN `formatReadingTime`): `3900` → "1h 5m",
/// `2700` → "45m", `3600` → "1h".
String formatReadingTime(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

/// RN drawer `InitialsAvatar`: split on single spaces, first char of each
/// part upper-cased, joined, first two characters ("Alice  B C" → "AB").
String userInitials(String name) {
  final joined = name
      .split(' ')
      .map((w) => w.isEmpty ? '' : String.fromCharCode(w.runes.first).toUpperCase())
      .join();
  final runes = joined.runes.toList();
  return String.fromCharCodes(runes.take(2));
}
