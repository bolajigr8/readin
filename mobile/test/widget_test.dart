import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/utils/book_visuals.dart';
import 'package:readin_flutter/utils/formatters.dart';

void main() {
  test('formatFileSize matches RN', () {
    expect(formatFileSize(0), '0 B');
    expect(formatFileSize(512), '512 B');
    expect(formatFileSize(1536), '1.5 KB');
    expect(formatFileSize(2097152), '2.0 MB');
  });

  test('getGreeting boundaries', () {
    expect(getGreeting(DateTime(2026, 1, 1, 11)), 'Good morning');
    expect(getGreeting(DateTime(2026, 1, 1, 12)), 'Good afternoon');
    expect(getGreeting(DateTime(2026, 1, 1, 17)), 'Good evening');
  });

  test('formatReadingTime', () {
    expect(formatReadingTime(3900), '1h 5m');
    expect(formatReadingTime(2700), '45m');
    expect(formatReadingTime(3600), '1h');
    expect(formatReadingTime(0), '0m');
  });

  test('titleInitials / coverColor follow format.ts', () {
    // RN: first letter of the first TWO words -> "Pride and" = PA
    expect(titleInitials('Pride and Prejudice'), 'PA');
    expect(titleInitials('The Great Gatsby'), 'TG');
    expect(titleInitials('Frankenstein'), 'FR');
    expect(titleInitials('Emma'), 'EM');
    // 'P' = 80, 80 % 8 = 0 -> first fallback colour
    expect(coverColor('Pride').toARGB32(), 0xFFF97316);
  });

  test('userInitials mirrors RN drawer avatar', () {
    expect(userInitials('Alice Smith'), 'AS');
    expect(userInitials('alice'), 'A');
    expect(userInitials('Alice  B C'), 'AB');
    expect(userInitials(''), '');
    expect(userInitials('Reader'), 'R');
  });
}
