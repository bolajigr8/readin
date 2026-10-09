import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/pressable_opacity.dart';

/// Section title (11 SemiBold ls .8 muted).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: AppTypography.label(
          size: 11,
          weight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppColors.textMuted,
        ),
      );
}

/// Rounded surface card that clips its rows.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(children: children),
    );
  }
}

/// RN `SettingsRow`: px16 py14 gap12, bottom border borderDefault@50 %,
/// icon tile 34 r10 colour@12.5 %, label 15, sublabel 12 muted.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.sublabel,
    this.onTap,
    this.rightContent,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? sublabel;
  final VoidCallback? onTap;
  final Widget? rightContent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: AppColors.alpha(AppColors.borderDefault, 0x80)),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.alpha(iconColor, 0x20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.body15),
                if (sublabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sublabel!,
                    style: AppTypography.label(size: 12, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (rightContent != null) ...[
            const SizedBox(width: 12),
            rightContent!,
          ] else if (onTap != null) ...[
            const SizedBox(width: 12),
            const Icon(Ionicons.chevron_forward, size: 16, color: AppColors.textMuted),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return PressableOpacity(pressedOpacity: 0.7, onTap: onTap, child: row);
  }
}

/// Switch styled like the RN one (track primary500 / borderDefault, white thumb).
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.primary500,
      inactiveTrackColor: AppColors.borderDefault,
      thumbColor: const WidgetStatePropertyAll<Color>(AppColors.white),
      trackOutlineColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    );
  }
}
