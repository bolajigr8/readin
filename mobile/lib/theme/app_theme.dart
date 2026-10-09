import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import 'app_typography.dart';

/// Colours that depend on the theme. Read with `context.customColors`.
///
/// ReadIn ships the dark palette only (`light` currently equals `dark`).
class CustomColors extends ThemeExtension<CustomColors> {
  const CustomColors({
    required this.bg,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.divider,
    required this.surfaceAlt,
    required this.border,
    required this.borderLight,
    required this.field,
    required this.fieldMuted,
    required this.card,
    required this.sheet,
    required this.hint,
    required this.brandTint,
  });

  final Color bg;
  final Color surface;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color divider;

  /// RN `elevated` (#1E1E1E).
  final Color surfaceAlt;
  final Color border;
  final Color borderLight;
  final Color field;
  final Color fieldMuted;
  final Color card;
  final Color sheet;
  final Color hint;
  final Color brandTint;

  static final CustomColors dark = CustomColors(
    bg: AppColors.background,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceMuted: AppColors.textSecondary,
    divider: AppColors.borderDefault,
    surfaceAlt: AppColors.elevated,
    border: AppColors.borderDefault,
    borderLight: AppColors.borderLight,
    field: AppColors.surface,
    fieldMuted: AppColors.elevated,
    card: AppColors.surface,
    sheet: AppColors.elevated,
    hint: AppColors.textMuted,
    brandTint: AppColors.alpha(AppColors.primary500, 0x14),
  );

  // TODO(light-mode): real light palette. Until then light == dark.
  static final CustomColors light = dark;

  @override
  CustomColors copyWith({
    Color? bg,
    Color? surface,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? divider,
    Color? surfaceAlt,
    Color? border,
    Color? borderLight,
    Color? field,
    Color? fieldMuted,
    Color? card,
    Color? sheet,
    Color? hint,
    Color? brandTint,
  }) {
    return CustomColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      divider: divider ?? this.divider,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      borderLight: borderLight ?? this.borderLight,
      field: field ?? this.field,
      fieldMuted: fieldMuted ?? this.fieldMuted,
      card: card ?? this.card,
      sheet: sheet ?? this.sheet,
      hint: hint ?? this.hint,
      brandTint: brandTint ?? this.brandTint,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return CustomColors(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      onSurface: mix(onSurface, other.onSurface),
      onSurfaceMuted: mix(onSurfaceMuted, other.onSurfaceMuted),
      divider: mix(divider, other.divider),
      surfaceAlt: mix(surfaceAlt, other.surfaceAlt),
      border: mix(border, other.border),
      borderLight: mix(borderLight, other.borderLight),
      field: mix(field, other.field),
      fieldMuted: mix(fieldMuted, other.fieldMuted),
      card: mix(card, other.card),
      sheet: mix(sheet, other.sheet),
      hint: mix(hint, other.hint),
      brandTint: mix(brandTint, other.brandTint),
    );
  }
}

/// Fade page transition (RN uses fade for tabs/reader).
class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(CustomColors.dark);

  /// Same palette as [dark] for now (see [CustomColors.light]).
  static ThemeData light() => _build(CustomColors.light);

  static ThemeData _build(CustomColors c) {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.primary500,
      onPrimary: AppColors.white,
      secondary: AppColors.amber400,
      onSecondary: AppColors.textInverse,
      surface: c.surface,
      onSurface: c.onSurface,
      error: AppColors.error500,
      onError: AppColors.white,
      outline: c.border,
    );

    final textTheme =
        AppTypography.buildTextTheme(c.onSurface, c.onSurfaceMuted);

    OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: color),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      colorScheme: colorScheme,
      textTheme: textTheme,
      fontFamily: AppTypography.fontFamily,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      dividerColor: c.divider,
      iconTheme: IconThemeData(color: c.onSurface),
      dividerTheme: DividerThemeData(color: c.divider, space: 1, thickness: 1),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadePageTransitionsBuilder(),
          TargetPlatform.iOS: _FadePageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(color: c.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        hintStyle: textTheme.bodyLarge?.copyWith(color: c.hint),
        border: inputBorder(c.border),
        enabledBorder: inputBorder(c.border),
        focusedBorder: inputBorder(c.border),
        errorBorder: inputBorder(AppColors.error500),
        focusedErrorBorder: inputBorder(AppColors.error500),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary500,
        selectionColor: AppColors.alpha(AppColors.primary500, 0x50),
        selectionHandleColor: AppColors.primary500,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary500,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.sheet,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.sheet,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.sheet,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[c],
    );
  }
}

extension ThemeContext on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Theme-dependent colours (`bg`, `surface`, `border`…).
  CustomColors get customColors => Theme.of(this).extension<CustomColors>()!;
}
