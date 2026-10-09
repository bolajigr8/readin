import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/pressable_opacity.dart';

/// RN `ReaderToolbar` (UI_SPEC §4.12): top bar + bottom bar over the page,
/// fade 200 ms, `box-none` when hidden.
class ReaderToolbar extends StatelessWidget {
  const ReaderToolbar({
    super.key,
    required this.title,
    required this.visible,
    required this.insets,
    required this.centerLabel,
    required this.percentage,
    this.timeLeft,
    required this.scrubEnabled,
    required this.onSeek,
    required this.navEnabled,
    required this.onBack,
    required this.bookmarked,
    required this.onBookmark,
    required this.onAnnotations,
    required this.onChapters,
    required this.onSettings,
    required this.onPrev,
    required this.onNext,
  });

  final String title;
  final bool visible;

  /// Safe-area insets captured **before** immersive mode hides the bars.
  final EdgeInsets insets;

  /// "Chapter 3 of 12" / "Page 4 of 120" / "Reading...".
  final String centerLabel;
  final int percentage;

  /// "~2h 10m left" (null = not known yet).
  final String? timeLeft;

  /// The progress scrubber can be used (EPUB: locations generated; PDF: pages known).
  final bool scrubEnabled;

  /// Called with a 0–1 fraction when the user releases the scrubber.
  final ValueChanged<double> onSeek;

  /// Prev/next buttons are dimmed (muted) when false (RN: totalChapters == 0).
  final bool navEnabled;

  /// The current location is bookmarked (icon filled, primary500).
  final bool bookmarked;

  /// Tap = toggle bookmark.
  final VoidCallback onBookmark;

  /// Long-press on the bookmark button = Annotations list.
  final VoidCallback onAnnotations;

  final VoidCallback onBack;
  final VoidCallback onChapters;
  final VoidCallback onSettings;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static final Color _barBg = AppColors.background.withValues(alpha: 0.88);

  Widget _iconBtn(
    IconData icon,
    VoidCallback onTap, {
    Color? color,
    VoidCallback? onLongPress,
    String? label,
  }) {
    return PressableOpacity(
      pressedOpacity: 0.7,
      semanticLabel: label,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.alpha(AppColors.surface, 0xCC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 22, color: color ?? AppColors.textPrimary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navColor = navEnabled ? AppColors.textPrimary : AppColors.textMuted;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top bar
            Container(
              height: insets.top + 56,
              padding: EdgeInsets.fromLTRB(16, insets.top + 8, 16, 12),
              decoration: BoxDecoration(
                color: _barBg,
                border: const Border(
                  bottom: BorderSide(color: AppColors.borderDefault),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _iconBtn(Ionicons.arrow_back, onBack, label: 'Back'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.label(size: 15, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _iconBtn(
                    bookmarked ? Ionicons.bookmark : Ionicons.bookmark_outline,
                    onBookmark,
                    color: bookmarked ? AppColors.primary500 : null,
                    onLongPress: onAnnotations,
                    label: bookmarked ? 'Remove bookmark' : 'Add bookmark',
                  ),
                  const SizedBox(width: 6),
                  _iconBtn(Ionicons.list_outline, onChapters, label: 'Table of contents'),
                  const SizedBox(width: 6),
                  _iconBtn(Ionicons.settings_outline, onSettings, label: 'Reader settings'),
                ],
              ),
            ),

            // Bottom bar
            Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, insets.bottom + 8),
              decoration: BoxDecoration(
                color: _barBg,
                border: const Border(
                  top: BorderSide(color: AppColors.borderDefault),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Scrubber(
                    value: percentage / 100.0,
                    enabled: scrubEnabled,
                    onSeek: onSeek,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _iconBtn(Ionicons.chevron_back, onPrev, color: navColor, label: 'Previous'),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              centerLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label(
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeLeft == null ? '$percentage%' : '$percentage% · $timeLeft',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label(
                                size: 14,
                                weight: FontWeight.w600,
                                color: AppColors.primary500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      _iconBtn(Ionicons.chevron_forward, onNext, color: navColor, label: 'Next'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin progress slider; shows the finger position while dragging and jumps on release.
class _Scrubber extends StatefulWidget {
  const _Scrubber({required this.value, required this.enabled, required this.onSeek});

  final double value;
  final bool enabled;
  final ValueChanged<double> onSeek;

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final v = (_drag ?? widget.value).clamp(0.0, 1.0).toDouble();
    return Opacity(
      opacity: widget.enabled ? 1 : 0.4,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          activeTrackColor: AppColors.primary500,
          inactiveTrackColor: AppColors.borderLight,
          thumbColor: AppColors.primary500,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          overlayColor: AppColors.alpha(AppColors.primary500, 0x25),
        ),
        child: SizedBox(
          height: 24,
          child: Slider(
            value: v,
            onChanged: widget.enabled ? (x) => setState(() => _drag = x) : null,
            onChangeEnd: widget.enabled
                ? (x) {
                    setState(() => _drag = null);
                    widget.onSeek(x);
                  }
                : null,
          ),
        ),
      ),
    );
  }
}
