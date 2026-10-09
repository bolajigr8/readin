import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_typography.dart';

/// Inline form error (login/register). Login uses alpha 0x18/0x40, register
/// uses Tailwind `/10` + `/30` = 0x1A/0x4D.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    this.fillAlpha = 0x18,
    this.borderAlpha = 0x40,
    this.radius = 10,
  });

  final String message;
  final int fillAlpha;
  final int borderAlpha;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.alpha(AppColors.error500, fillAlpha),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.alpha(AppColors.error500, borderAlpha)),
      ),
      child: Text(
        message,
        style: AppTypography.label(
          size: 14,
          color: AppColors.error400,
          lineHeight: 20,
        ),
      ),
    );
  }
}
