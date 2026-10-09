import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Content wrapper for bottom sheets (UI_SPEC §2): handle 36×4 r2 borderLight,
/// top radius 20, elevated background, 1 px top border.
class BottomSheetScaffold extends StatelessWidget {
  const BottomSheetScaffold({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.elevated,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
            SizedBox(height: bottom > 0 ? 0 : 12),
          ],
        ),
      ),
    );
  }
}

/// Shows [builder] in the standard ReadIn sheet (tap outside closes,
/// ~280 ms ease-out slide ≈ RN spring).
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    elevation: 0,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 280),
      reverseDuration: Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    ),
    builder: builder,
  );
}
