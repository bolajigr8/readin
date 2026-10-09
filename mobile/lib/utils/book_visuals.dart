import 'package:flutter/painting.dart';

import '../constants/app_colors.dart';

/// RN `getCoverColor`: deterministic colour from the first char code.
Color coverColor(String title) {
  final code = title.isEmpty ? 65 : title.codeUnitAt(0);
  return AppColors.coverFallbacks[code % AppColors.coverFallbacks.length];
}

/// RN `getTitleInitials`: one word → first 2 letters; else first letters of
/// the first two words. Always upper-case.
String titleInitials(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return '';
  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length == 1) {
    return (title.length >= 2 ? title.substring(0, 2) : title).toUpperCase();
  }
  return words
      .take(2)
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
      .join();
}
