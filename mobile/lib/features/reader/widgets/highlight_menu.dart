import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../annotations/data/annotation_models.dart';

/// RN `HighlightMenu` (UI_SPEC §4.12) with two extra actions:
///
/// * row 1: quote preview (≤ 80 chars) · 5 colour swatches · close
/// * row 2: **Note** · **Copy** · **Define** (only for a single word)
///
/// (RN put swatches + Note + close on one row — too wide for a phone once more
/// actions are added.) The tap-outside layer exists only while visible.
class HighlightMenu extends StatelessWidget {
  const HighlightMenu({
    super.key,
    required this.isVisible,
    required this.selectedText,
    required this.onHighlight,
    required this.onAddNote,
    required this.onCopy,
    required this.onShareCard,
    required this.onDismiss,
    this.onDefine,
  });

  final bool isVisible;
  final String selectedText;
  final ValueChanged<HighlightColor> onHighlight;
  final VoidCallback onAddNote;
  final VoidCallback onCopy;
  final VoidCallback onShareCard;

  /// null = the selection is not a single word (no "Define").
  final VoidCallback? onDefine;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final preview = selectedText.length > 80
        ? '${selectedText.substring(0, 80)}...'
        : selectedText;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (isVisible)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 80,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: AnimatedSlide(
              offset: isVisible ? Offset.zero : const Offset(0, 1.2),
              duration: const Duration(milliseconds: 260),
              curve: isVisible ? Curves.easeOutBack : Curves.easeIn,
              child: AnimatedOpacity(
                opacity: isVisible ? 1 : 0,
                duration: Duration(milliseconds: isVisible ? 200 : 150),
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (selectedText.isNotEmpty) ...[
                          Text(
                            '"$preview"',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label(
                              size: 13,
                              color: AppColors.textSecondary,
                              lineHeight: 18,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            for (final c in HighlightColor.values) ...[
                              if (c != HighlightColor.yellow) const SizedBox(width: 10),
                              PressableOpacity(
                                pressedOpacity: 0.8,
                                semanticLabel: 'Highlight ${c.label}',
                                onTap: () => onHighlight(c),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: c.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.white.withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            PressableOpacity(
                              pressedOpacity: 0.7,
                              semanticLabel: 'Close',
                              onTap: onDismiss,
                              child: const SizedBox(
                                width: 30,
                                height: 30,
                                child: Icon(
                                  Ionicons.close,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _Action(
                                icon: Ionicons.create_outline,
                                label: 'Note',
                                primary: true,
                                onTap: onAddNote,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _Action(
                                icon: Ionicons.copy_outline,
                                label: 'Copy',
                                onTap: onCopy,
                              ),
                            ),
                            if (onDefine != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Action(
                                  icon: Ionicons.book_outline,
                                  label: 'Define',
                                  onTap: onDefine!,
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Expanded(
                              child: _Action(
                                icon: Ionicons.image_outline,
                                label: 'Card',
                                onTap: onShareCard,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final color = primary ? AppColors.primary500 : AppColors.textSecondary;
    return PressableOpacity(
      pressedOpacity: 0.8,
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: primary
              ? AppColors.alpha(AppColors.primary500, 0x18)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: primary
                ? AppColors.alpha(AppColors.primary500, 0x40)
                : AppColors.borderDefault,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.label(size: 13, weight: FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
