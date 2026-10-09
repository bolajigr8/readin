import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../theme/app_typography.dart';
import 'pressable_opacity.dart';

enum AppButtonVariant { primary, secondary, outline, ghost }

enum AppButtonSize { sm, md, lg }

/// RN `ui/Button` (UI_SPEC §2). Row, centred, gap 8, opacity .5 when disabled.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.loading = false,
    this.leftIcon,
    this.rightIcon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;
  final Widget? leftIcon;
  final Widget? rightIcon;

  /// Fill the available width (RN buttons stretch inside a column).
  final bool expand;

  bool get _disabled => onPressed == null || loading;

  Color get _bg => switch (variant) {
        AppButtonVariant.primary => AppColors.primary500,
        AppButtonVariant.secondary => AppColors.elevated,
        _ => Colors.transparent,
      };

  Color get _border => switch (variant) {
        AppButtonVariant.primary => AppColors.primary500,
        AppButtonVariant.secondary => AppColors.borderDefault,
        AppButtonVariant.outline => AppColors.primary500,
        AppButtonVariant.ghost => Colors.transparent,
      };

  Color get _fg => switch (variant) {
        AppButtonVariant.primary => AppColors.white,
        AppButtonVariant.secondary => AppColors.textPrimary,
        AppButtonVariant.outline => AppColors.primary500,
        AppButtonVariant.ghost => AppColors.textSecondary,
      };

  FontWeight get _weight => variant == AppButtonVariant.ghost
      ? FontWeight.w500
      : FontWeight.w600;

  EdgeInsets get _padding => switch (size) {
        AppButtonSize.sm => const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        AppButtonSize.md => const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        AppButtonSize.lg => const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      };

  double get _radius => size == AppButtonSize.sm
      ? AppDimensions.radiusSm
      : AppDimensions.radiusMd;

  double get _fontSize => switch (size) {
        AppButtonSize.sm => 14,
        AppButtonSize.md => 16,
        AppButtonSize.lg => 18,
      };

  double get _lineHeight => switch (size) {
        AppButtonSize.sm => 20,
        AppButtonSize.md => 24,
        AppButtonSize.lg => 28,
      };

  @override
  Widget build(BuildContext context) {
    final spinnerColor =
        variant == AppButtonVariant.primary ? AppColors.white : AppColors.primary500;

    final children = <Widget>[
      if (loading)
        SizedBox(
          width: 20,
          height: _lineHeight,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: spinnerColor,
              ),
            ),
          ),
        )
      else ...[
        if (leftIcon != null) ...[leftIcon!, const SizedBox(width: 8)],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label(
              size: _fontSize,
              weight: _weight,
              color: _fg,
              lineHeight: _lineHeight,
            ),
          ),
        ),
        if (rightIcon != null) ...[const SizedBox(width: 8), rightIcon!],
      ],
    ];

    final body = AnimatedOpacity(
      opacity: _disabled ? 0.5 : 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        padding: _padding,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        ),
      ),
    );

    return PressableOpacity(onTap: _disabled ? null : onPressed, child: body);
  }
}
