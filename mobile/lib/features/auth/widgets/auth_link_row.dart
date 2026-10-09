import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';

/// "Don't have an account? **Sign up**" row (14 secondary / 14 SemiBold primary).
class AuthLinkRow extends StatelessWidget {
  const AuthLinkRow({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
    this.lineHeight,
  });

  /// Register uses Tailwind `text-sm` (20); login uses inline styles (none).
  final double? lineHeight;
  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prompt,
          style: AppTypography.label(
            size: 14,
            color: AppColors.textSecondary,
            lineHeight: lineHeight,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Text(
            action,
            style: AppTypography.label(
              size: 14,
              weight: FontWeight.w600,
              color: AppColors.primary500,
              lineHeight: lineHeight,
            ),
          ),
        ),
      ],
    );
  }
}

/// "← Back" link used on register / forgot.
class AuthBackLink extends StatelessWidget {
  const AuthBackLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          '← Back',
          style: AppTypography.label(
            size: 14,
            color: AppColors.textSecondary,
            lineHeight: 20,
          ),
        ),
      ),
    );
  }
}

/// Success card: 64 circle + emoji, title 24 Bold, body 16 secondary lh 24.
class AuthSuccessBlock extends StatelessWidget {
  const AuthSuccessBlock({
    super.key,
    required this.circleColor,
    required this.emoji,
    required this.title,
    required this.message,
  });

  final Color circleColor;
  final String emoji;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: circleColor),
          child: Text(emoji, style: const TextStyle(fontSize: 36, height: 1.2)),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.label(
            size: 24,
            weight: FontWeight.w700,
            lineHeight: 32,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.label(
            size: 16,
            color: AppColors.textSecondary,
            lineHeight: 24,
          ),
        ),
      ],
    );
  }
}
