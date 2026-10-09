import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../constants/app_colors.dart';
import '../providers/drawer_provider.dart';
import '../theme/app_typography.dart';
import 'pressable_opacity.dart';

/// RN `AppHeader` (UI_SPEC §2): menu button · centred title · 40 px right slot.
class AppHeader extends ConsumerWidget {
  const AppHeader({super.key, required this.title, this.rightContent});

  final String title;
  final Widget? rightContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 8, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: [
          PressableOpacity(
            pressedOpacity: 0.7,
            semanticLabel: 'Open menu',
            onTap: () => ref.read(drawerOpenProvider.notifier).state = true,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Ionicons.menu,
                size: 24,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.section17,
            ),
          ),
          SizedBox(
            width: 40,
            child: Align(
              alignment: Alignment.centerRight,
              child: rightContent ?? const SizedBox(width: 40),
            ),
          ),
        ],
      ),
    );
  }
}
