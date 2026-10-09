import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_typography.dart';

/// Dark confirm dialog (RN uses the native `Alert.alert`).
/// Resolves to `true` only when the user taps the confirm button.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'OK',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  bool hideCancel = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.elevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      title: Text(title, style: AppTypography.section17),
      content: message == null
          ? null
          : Text(
              message,
              style: AppTypography.label(
                size: 14,
                color: AppColors.textSecondary,
                lineHeight: 20,
              ),
            ),
      actions: [
        if (!hideCancel)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              cancelLabel,
              style: AppTypography.label(
                size: 14,
                weight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            confirmLabel,
            style: AppTypography.label(
              size: 14,
              weight: FontWeight.w600,
              color: destructive ? AppColors.error500 : AppColors.primary500,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Single-button dark alert (RN `Alert.alert(title, message)`).
Future<void> showAlertDialog(
  BuildContext context, {
  required String title,
  String? message,
  String buttonLabel = 'OK',
}) async {
  await showConfirmDialog(
    context,
    title: title,
    message: message,
    confirmLabel: buttonLabel,
    cancelLabel: '',
    hideCancel: true,
  );
}
