import 'package:flutter/widgets.dart';

import '../core/widgets/app_loader.dart';

/// RN `LoadingSpinner` (`size: 'small' | 'large'` → 20 / 36).
class LoadingSpinner extends StatelessWidget {
  const LoadingSpinner({
    super.key,
    this.fullScreen = false,
    this.label,
    this.small = false,
  });

  final bool fullScreen;
  final String? label;
  final bool small;

  @override
  Widget build(BuildContext context) => AppLoader(
        fullScreen: fullScreen,
        label: label,
        size: small ? 20 : 36,
      );
}
