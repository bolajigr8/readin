import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_typography.dart';

/// RN `LoadingSpinner`. [fullScreen] = centred on the app background.
class AppLoader extends StatelessWidget {
  const AppLoader({
    super.key,
    this.fullScreen = false,
    this.label,
    this.size = 36,
  });

  final bool fullScreen;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.primary500,
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(
            label!,
            style: AppTypography.label(
              size: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );

    if (fullScreen) {
      return ColoredBox(
        color: AppColors.background,
        child: SizedBox.expand(child: Center(child: content)),
      );
    }
    return Center(child: content);
  }
}
