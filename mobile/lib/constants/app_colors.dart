import 'package:flutter/painting.dart';

/// Every colour token of ReadIn (ported 1:1 from RN `constants/theme.ts`).
///
/// Rule: never hard-code a hex outside this file.
class AppColors {
  AppColors._();

  // Surfaces
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF141414);
  static const Color elevated = Color(0xFF1E1E1E);

  // Primary (orange)
  static const Color primary300 = Color(0xFFFCD34D);
  static const Color primary400 = Color(0xFFFB923C);
  static const Color primary500 = Color(0xFFF97316);
  static const Color primary600 = Color(0xFFEA6C0A);
  static const Color primary700 = Color(0xFFC2570A);

  // Amber
  static const Color amber300 = Color(0xFFFCD34D);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber600 = Color(0xFFD97706);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF52525B);
  static const Color textInverse = Color(0xFF0A0A0A);

  // Borders
  static const Color borderDefault = Color(0xFF2A2A2A);
  static const Color borderLight = Color(0xFF3A3A3A);

  // Status
  static const Color success400 = Color(0xFF4ADE80);
  static const Color success500 = Color(0xFF22C55E);
  static const Color success600 = Color(0xFF16A34A);

  static const Color error400 = Color(0xFFF87171);
  static const Color error500 = Color(0xFFEF4444);
  static const Color error600 = Color(0xFFDC2626);

  static const Color warning400 = Color(0xFFFCD34D);
  static const Color warning500 = Color(0xFFF59E0B);
  static const Color warning600 = Color(0xFFD97706);

  // Misc
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color purple500 = Color(0xFFA855F7);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  // Reader link colour
  static const Color readerLink = Color(0xFFFB923C);

  // Highlight colours (reader annotations)
  static const Color highlightYellow = Color(0xFFFDE68A);
  static const Color highlightGreen = Color(0xFF6EE7B7);
  static const Color highlightBlue = Color(0xFF93C5FD);
  static const Color highlightPink = Color(0xFFF9A8D4);
  static const Color highlightPurple = Color(0xFFC4B5FD);

  static const List<Color> highlights = [
    highlightYellow,
    highlightGreen,
    highlightBlue,
    highlightPink,
    highlightPurple,
  ];

  /// Cover fallback colours; index = first char code % 8.
  static const List<Color> coverFallbacks = [
    Color(0xFFF97316),
    Color(0xFFFBBF24),
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFFA855F7),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFFF472B6),
  ];

  /// Ports RN's `color + '25'` (hex alpha suffix) 1:1.
  ///
  /// `AppColors.alpha(AppColors.primary500, 0x25)` == RN `'#F97316' + '25'`.
  static Color alpha(Color c, int hexAlpha) =>
      c.withValues(alpha: hexAlpha.clamp(0, 255) / 255);
}

/// Reader theme palette (RN `THEME.reader`).
class ReaderPalette {
  const ReaderPalette({required this.bg, required this.fg});

  final Color bg;
  final Color fg;

  static const light = ReaderPalette(
    bg: Color(0xFFFFFFFF),
    fg: Color(0xFF1A1A1A),
  );
  static const dark = ReaderPalette(
    bg: Color(0xFF0A0A0A),
    fg: Color(0xFFE4E4E7),
  );
  static const night = ReaderPalette(
    bg: Color(0xFF000000),
    fg: Color(0xFFB4B4B4),
  );
  static const sepia = ReaderPalette(
    bg: Color(0xFFF5E6C8),
    fg: Color(0xFF3D2B1F),
  );

  static ReaderPalette byName(String name) => switch (name) {
        'light' => light,
        'sepia' => sepia,
        'night' => night,
        _ => dark,
      };
}
