import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_typography.dart';
import 'buttons.dart';

/// RN `EmptyState` (UI_SPEC §2).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.borderDefault),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.elevated,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 40, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title20,
            ),
            const SizedBox(height: 16),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTypography.label(
                size: 15,
                color: AppColors.textSecondary,
                lineHeight: 23,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              AppButton(
                label: actionLabel!,
                variant: AppButtonVariant.outline,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
