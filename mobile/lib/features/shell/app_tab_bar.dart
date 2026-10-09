import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/pressable_opacity.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.iconActive);
  final String label;
  final IconData icon;
  final IconData iconActive;
}

const List<_Tab> _tabs = [
  _Tab('Home', Ionicons.home_outline, Ionicons.home),
  _Tab('Library', Ionicons.library_outline, Ionicons.library),
  _Tab('Discover', Ionicons.compass_outline, Ionicons.compass),
  _Tab('Profile', Ionicons.person_outline, Ionicons.person),
];

/// RN bottom tab bar (UI_SPEC §3): bg surface, 1 px top border, height
/// `56 + bottomInset`, paddingTop 8, paddingBottom `max(inset, 6)`, elevation 8,
/// icons 24, label Inter Medium 11, active primary500 / inactive muted.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // viewPadding (not padding): stays constant while the keyboard is open.
    final inset = math.max(MediaQuery.viewPaddingOf(context).bottom, 0.0);

    return Container(
      height: 56 + inset,
      padding: EdgeInsets.only(top: 8, bottom: math.max(inset, 6)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.borderDefault)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: PressableOpacity(
                pressedOpacity: 0.7,
                semanticLabel: '${_tabs[i].label} tab',
                onTap: () {
                  if (i != currentIndex) HapticFeedback.selectionClick();
                  onTap(i);
                },
                child: _TabItem(tab: _tabs[i], active: i == currentIndex),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.active});

  final _Tab tab;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary500 : AppColors.textMuted;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(active ? tab.iconActive : tab.icon, size: 24, color: color),
        const SizedBox(height: 1),
        Text(
          tab.label,
          maxLines: 1,
          style: AppTypography.label(
            size: 11,
            weight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
