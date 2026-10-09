import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

/// ReadIn typography: **Inter** everywhere.
///
/// Fonts come from the `google_fonts` package (downloaded on first launch and
/// cached; the very first launch needs internet, otherwise the system font
/// is used). To bundle Inter instead, drop the TTFs in `assets/fonts/`,
/// declare them in pubspec and change [label] below.
class AppTypography {
  AppTypography._();

  static String get fontFamily => GoogleFonts.inter().fontFamily!;

  /// Generic style helper. [lineHeight] is in px (RN `lineHeight`).
  static TextStyle label({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double? lineHeight,
    double? letterSpacing,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) {
    // NOTE: weight must be passed to GoogleFonts.inter() itself. Using
    // `GoogleFonts.inter().copyWith(fontWeight: ...)` keeps the Regular file
    // and fakes the weight (blurry faux-bold).
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: lineHeight == null ? null : lineHeight / size,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      decoration: decoration,
    );
  }

  // Named styles that match RN usage.
  static TextStyle get h1 =>
      label(size: 36, weight: FontWeight.w700, lineHeight: 44);
  static TextStyle get title22 => label(size: 22, weight: FontWeight.w600);
  static TextStyle get title20 => label(size: 20, weight: FontWeight.w600);
  static TextStyle get section17 => label(size: 17, weight: FontWeight.w600);
  static TextStyle get body16 => label(size: 16);
  static TextStyle get body15 => label(size: 15);
  static TextStyle get body14 => label(size: 14);
  static TextStyle get caption13 => label(size: 13);
  static TextStyle get caption12 => label(size: 12);
  static TextStyle get micro11 => label(size: 11);
  static TextStyle get micro10 => label(size: 10);

  /// Flutter [TextTheme] so stock widgets (TextField, dialogs…) match.
  static TextTheme buildTextTheme(Color onSurface, Color onSurfaceMuted) {
    TextStyle s(double size, FontWeight w, [Color? c]) =>
        label(size: size, weight: w, color: c ?? onSurface);
    return TextTheme(
      displayLarge: s(36, FontWeight.w700),
      displayMedium: s(28, FontWeight.w700),
      displaySmall: s(24, FontWeight.w700),
      headlineLarge: s(22, FontWeight.w600),
      headlineMedium: s(20, FontWeight.w600),
      headlineSmall: s(17, FontWeight.w600),
      titleLarge: s(17, FontWeight.w600),
      titleMedium: s(16, FontWeight.w600),
      titleSmall: s(15, FontWeight.w600),
      bodyLarge: s(16, FontWeight.w400),
      bodyMedium: s(14, FontWeight.w400, onSurfaceMuted),
      bodySmall: s(12, FontWeight.w400, onSurfaceMuted),
      labelLarge: s(16, FontWeight.w600),
      labelMedium: s(13, FontWeight.w500),
      labelSmall: s(11, FontWeight.w500, onSurfaceMuted),
    );
  }
}
