import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../profile/widgets/settings_row.dart' show AppSwitch;
import '../data/reader_models.dart';
import 'slide_panel.dart';

/// Reader settings (RN `ReaderSettings` + typography, layout, brightness, volume keys).
///
/// Layout rule that fixes the "RIGHT OVERFLOWED" bug: every setting is a
/// **vertical** block (label row, then a full-width row of equal chips), so
/// nothing can be wider than the sheet; the whole sheet scrolls on small screens.
class ReaderSettingsSheet extends StatelessWidget {
  const ReaderSettingsSheet({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.prefs,
    required this.onFontSize,
    required this.onFontFamily,
    required this.onTheme,
    required this.onLineHeight,
    required this.onMargin,
    required this.onAlign,
    required this.onFlow,
    required this.onBrightness,
    required this.onVolumeKeys,
    required this.onWarmth,
    required this.onAutoNight,
    required this.autoScrollLevel,
    required this.onAutoScroll,
    required this.onOpenSounds,
    required this.readAloudActive,
    required this.onReadAloud,
    this.showPageLayout = true,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final ReaderPrefs prefs;
  final ValueChanged<double> onFontSize;
  final ValueChanged<String> onFontFamily;
  final ValueChanged<String> onTheme;
  final ValueChanged<double> onLineHeight;
  final ValueChanged<double> onMargin;
  final ValueChanged<String> onAlign;
  final ValueChanged<String> onFlow;
  final ValueChanged<double> onBrightness;
  final ValueChanged<bool> onVolumeKeys;
  final ValueChanged<double> onWarmth;
  final ValueChanged<bool> onAutoNight;

  /// 0 off · 1 slow · 2 medium · 3 fast
  final int autoScrollLevel;
  final ValueChanged<int> onAutoScroll;
  final VoidCallback onOpenSounds;
  final bool readAloudActive;
  final VoidCallback onReadAloud;

  /// EPUB-only options (spacing, margins, alignment, paged/scroll) are hidden for PDFs.
  final bool showPageLayout;

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    final size = prefs.fontSize.round();

    return SlidePanel(
      isOpen: isOpen,
      onClose: onClose,
      edge: PanelEdge.bottom,
      backdropOpacity: 0, // RN: invisible tap-outside layer
      showBackdrop: false,
      slideDistance: 600,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: AppColors.elevated,
          border: Border(top: BorderSide(color: AppColors.borderLight)),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 12, 24, viewPadding.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reader Settings',
                textAlign: TextAlign.center,
                style: AppTypography.label(size: 16, weight: FontWeight.w600),
              ),
              const SizedBox(height: 20),

              // Font size (stepper, fits the row)
              _Header(
                icon: Ionicons.text_outline,
                color: AppColors.primary500,
                label: 'Font Size',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StepButton(
                        icon: Ionicons.remove_circle_outline,
                        enabled: size > 12,
                        label: 'Smaller text',
                        onTap: () => onFontSize(prefs.fontSize - 2),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '$size',
                          textAlign: TextAlign.center,
                          style: AppTypography.label(size: 17, weight: FontWeight.w600),
                        ),
                      ),
                      _StepButton(
                        icon: Ionicons.add_circle_outline,
                        enabled: size < 28,
                        label: 'Larger text',
                        onTap: () => onFontSize(prefs.fontSize + 2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _Block(
                icon: Ionicons.book_outline,
                color: AppColors.amber400,
                label: 'Font Style',
                child: _WrapChips<String>(
                  value: prefs.fontFamily,
                  onSelect: onFontFamily,
                  options: const [
                    _Opt('Sans', 'sans-serif'),
                    _Opt('Serif', 'serif'),
                    _Opt('Literata', 'literata'),
                    _Opt('Merriweather', 'merriweather'),
                    _Opt('Lora', 'lora'),
                    _Opt('Lexend · easy reading', 'lexend'),
                    _Opt('Atkinson · high clarity', 'atkinson'),
                    _Opt('OpenDyslexic', 'opendyslexic'),
                  ],
                ),
              ),
              if (prefs.fontFamily != 'sans-serif' && prefs.fontFamily != 'serif')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Web fonts download the first time you use them (needs internet).',
                    style: AppTypography.label(size: 11, color: AppColors.textMuted),
                  ),
                ),

              _Block(
                icon: Ionicons.color_palette_outline,
                color: AppColors.purple500,
                label: 'Theme',
                child: _Chips<String>(
                  value: prefs.theme,
                  onSelect: onTheme,
                  options: [
                    _Opt('Light', 'light', swatch: ReaderPalette.light.bg),
                    _Opt('Dark', 'dark', swatch: ReaderPalette.dark.bg),
                    _Opt('Sepia', 'sepia', swatch: ReaderPalette.sepia.bg),
                    _Opt('Night', 'night', swatch: ReaderPalette.night.bg),
                  ],
                ),
              ),

              if (showPageLayout) ...[
                _Block(
                  icon: Ionicons.reorder_four_outline,
                  color: AppColors.blue500,
                  label: 'Line Spacing',
                  child: _Chips<double>(
                    value: _nearest(prefs.lineHeight, const [1.4, 1.6, 1.8, 2.0]),
                    onSelect: onLineHeight,
                    options: const [
                      _Opt('Tight', 1.4),
                      _Opt('Normal', 1.6),
                      _Opt('Relaxed', 1.8),
                      _Opt('Airy', 2.0),
                    ],
                  ),
                ),
                _Block(
                  icon: Ionicons.resize_outline,
                  color: AppColors.success500,
                  label: 'Margins',
                  child: _Chips<double>(
                    value: _nearest(prefs.margin, const [4.0, 16.0, 32.0]),
                    onSelect: onMargin,
                    options: const [
                      _Opt('Narrow', 4.0),
                      _Opt('Medium', 16.0),
                      _Opt('Wide', 32.0),
                    ],
                  ),
                ),
                _Block(
                  icon: Ionicons.menu_outline,
                  color: AppColors.primary400,
                  label: 'Alignment',
                  child: _Chips<String>(
                    value: prefs.align,
                    onSelect: onAlign,
                    options: const [
                      _Opt('Left', 'left'),
                      _Opt('Justified', 'justify'),
                    ],
                  ),
                ),
                _Block(
                  icon: Ionicons.swap_horizontal_outline,
                  color: AppColors.amber500,
                  label: 'Page Layout',
                  child: _Chips<String>(
                    value: prefs.flow,
                    onSelect: onFlow,
                    options: const [
                      _Opt('Paged', 'paged'),
                      _Opt('Scroll', 'scroll'),
                    ],
                  ),
                ),
              ],

              // Brightness (software dimmer)
              _Block(
                icon: Ionicons.sunny_outline,
                color: AppColors.amber400,
                label: 'Dimmer',
                trailing: Text(
                  '${(prefs.brightness * 100).round()}%',
                  style: AppTypography.label(size: 13, color: AppColors.textMuted),
                ),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: AppColors.primary500,
                    inactiveTrackColor: AppColors.borderLight,
                    thumbColor: AppColors.primary500,
                    overlayColor: AppColors.alpha(AppColors.primary500, 0x25),
                  ),
                  child: Slider(
                    value: prefs.brightness.clamp(0.3, 1.0).toDouble(),
                    min: 0.3,
                    max: 1.0,
                    onChanged: onBrightness,
                  ),
                ),
              ),

              // Warm filter + auto night
              _Block(
                icon: Ionicons.moon_outline,
                color: AppColors.primary400,
                label: 'Warm Filter',
                trailing: Text(
                  prefs.warmth == 0 ? 'Off' : '${(prefs.warmth * 200).round()}%',
                  style: AppTypography.label(size: 13, color: AppColors.textMuted),
                ),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: AppColors.primary500,
                    inactiveTrackColor: AppColors.borderLight,
                    thumbColor: AppColors.primary500,
                    overlayColor: AppColors.alpha(AppColors.primary500, 0x25),
                  ),
                  child: Slider(
                    value: prefs.warmth.clamp(0.0, 0.5).toDouble(),
                    min: 0,
                    max: 0.5,
                    onChanged: onWarmth,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    const _IconTile(icon: Ionicons.partly_sunny_outline, color: AppColors.purple500),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Auto Night Theme', style: AppTypography.label(size: 15, weight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(
                            'Night theme from 8 pm to 6 am',
                            style: AppTypography.label(size: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    AppSwitch(value: prefs.autoNight, onChanged: onAutoNight),
                  ],
                ),
              ),

              // Auto-scroll + sounds + read aloud
              if (showPageLayout)
                _Block(
                  icon: Ionicons.play_forward_outline,
                  color: AppColors.success500,
                  label: prefs.isScroll ? 'Auto-scroll' : 'Auto page turn',
                  child: _Chips<int>(
                    value: autoScrollLevel,
                    onSelect: onAutoScroll,
                    options: const [
                      _Opt('Off', 0),
                      _Opt('Slow', 1),
                      _Opt('Medium', 2),
                      _Opt('Fast', 3),
                    ],
                  ),
                ),
              _ActionRow(
                icon: Ionicons.headset_outline,
                color: AppColors.blue500,
                title: 'Focus Sounds',
                subtitle: 'Rain, ocean, fireplace, café…',
                actionLabel: 'Open',
                onTap: onOpenSounds,
              ),
              if (showPageLayout)
                _ActionRow(
                  icon: Ionicons.volume_medium_outline,
                  color: AppColors.primary500,
                  title: 'Read Aloud',
                  subtitle: 'Highlights the sentence as it speaks',
                  actionLabel: readAloudActive ? 'Stop' : 'Start',
                  onTap: onReadAloud,
                ),

              // Volume keys
              Row(
                children: [
                  const _IconTile(icon: Ionicons.volume_high_outline, color: AppColors.blue500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Volume Buttons Turn Pages',
                          style: AppTypography.label(size: 15, weight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Up = previous, Down = next',
                          style: AppTypography.label(size: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  AppSwitch(value: prefs.volumeKeys, onChanged: onVolumeKeys),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Snaps a stored value to the closest chip so an old/custom value still
  /// highlights something.
  static double _nearest(double v, List<double> options) {
    var best = options.first;
    for (final o in options) {
      if ((o - v).abs() < (best - v).abs()) best = o;
    }
    return best;
  }
}

class _Opt<T> {
  const _Opt(this.label, this.value, {this.swatch});
  final String label;
  final T value;
  final Color? swatch;
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      );
}

/// Label row (+ optional trailing widget).
class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.color,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconTile(icon: icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label(size: 15, weight: FontWeight.w500),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Vertical setting block: header on top, control below (always full width).
class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.color,
    required this.label,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(icon: icon, color: color, label: label, trailing: trailing),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Equal-width chips filling the row; labels scale down instead of overflowing.
class _Chips<T> extends StatelessWidget {
  const _Chips({required this.value, required this.options, required this.onSelect});

  final T value;
  final List<_Opt<T>> options;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Chip(
              label: options[i].label,
              swatch: options[i].swatch,
              active: options[i].value == value,
              onTap: () => onSelect(options[i].value),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.swatch,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    return PressableOpacity(
      pressedOpacity: 0.75,
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.alpha(AppColors.primary500, 0x15) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.primary500 : AppColors.borderDefault,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (swatch != null) ...[
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                maxLines: 1,
                style: AppTypography.label(
                  size: 13,
                  weight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? AppColors.primary500 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PressableOpacity(
      pressedOpacity: 0.7,
      semanticLabel: label,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(
          icon,
          size: 24,
          color: enabled ? AppColors.primary500 : AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Row with a title and a small action button (Open / Start / Stop).
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          _IconTile(icon: icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.label(size: 15, weight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.label(size: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PressableOpacity(
            pressedOpacity: 0.75,
            semanticLabel: '$title $actionLabel',
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.alpha(AppColors.primary500, 0x15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary500),
              ),
              child: Text(
                actionLabel,
                style: AppTypography.label(size: 13, weight: FontWeight.w600, color: AppColors.primary500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chips that keep their natural width and wrap onto more lines (many options).
class _WrapChips<T> extends StatelessWidget {
  const _WrapChips({required this.value, required this.options, required this.onSelect});

  final T value;
  final List<_Opt<T>> options;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          _Chip(
            label: o.label,
            swatch: o.swatch,
            active: o.value == value,
            onTap: () => onSelect(o.value),
          ),
      ],
    );
  }
}
