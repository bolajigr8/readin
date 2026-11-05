import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../profile/widgets/settings_row.dart' show AppSwitch;
import '../data/reader_models.dart';

/// The small settings panel under the ⚙ button (like the reference reader):
/// page flipping, colour mode, font, size, thickness, line spacing, text align
/// and page margins — everything changes the page LIVE. "General settings"
/// opens the full panel (brightness, warm filter, sounds, read aloud…).
class ReaderQuickSettings extends StatefulWidget {
  const ReaderQuickSettings({
    super.key,
    required this.prefs,
    required this.onFlow,
    required this.onTheme,
    required this.onFontFamily,
    required this.onFontSize,
    required this.onFontWeight,
    required this.onLineHeight,
    required this.onAlignMode,
    required this.onMarginsOn,
    required this.onPageAnim,
    required this.onGeneral,
  });

  final ReaderPrefs prefs;
  final ValueChanged<String> onFlow;
  final ValueChanged<String> onTheme;
  final ValueChanged<String> onFontFamily;
  final ValueChanged<double> onFontSize;
  final ValueChanged<int> onFontWeight;
  final ValueChanged<double> onLineHeight;

  /// 0 = left · 1 = justified · 2 = justified + hyphenation
  final ValueChanged<int> onAlignMode;
  final ValueChanged<bool> onMarginsOn;
  final ValueChanged<String> onPageAnim;
  final VoidCallback onGeneral;

  @override
  State<ReaderQuickSettings> createState() => _ReaderQuickSettingsState();
}

class _ReaderQuickSettingsState extends State<ReaderQuickSettings> {
  String? _open; // which dropdown row is expanded

  int get _alignMode => widget.prefs.align == 'justify' ? (widget.prefs.hyphenate ? 2 : 1) : 0;

  static const _themes = <(String, String)>[
    ('sepia', 'Sepia'),
    ('light', 'Light'),
    ('dark', 'Dark'),
    ('night', 'Night (black)'),
  ];

  static const _aligns = <(int, String)>[
    (0, 'Left'),
    (1, 'Justified'),
    (2, 'Justified + hyphenation'),
  ];

  void _toggle(String id) => setState(() => _open = _open == id ? null : id);

  @override
  Widget build(BuildContext context) {
    final p = widget.prefs;
    final themeLabel = _themes.firstWhere((t) => t.$1 == p.theme, orElse: () => _themes.first).$2;
    final alignLabel = _aligns.firstWhere((a) => a.$1 == _alignMode).$2;
    final weightIndex = kFontWeights.indexOf(p.fontWeight).clamp(0, kFontWeights.length - 1);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'READING SETTINGS',
                    textAlign: TextAlign.center,
                    style: AppTypography.label(
                      size: 11,
                      weight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.primary500,
                    ),
                  ),
                ),

                _DropRow(
                  label: 'PAGE FLIPPING',
                  value: p.flow == 'scroll' ? 'Vertical (scroll)' : 'Horizontal (pages)',
                  open: _open == 'flow',
                  onTap: () => _toggle('flow'),
                  options: [
                    _Choice('Horizontal (pages)', p.flow != 'scroll', () => widget.onFlow('paged')),
                    _Choice('Vertical (scroll)', p.flow == 'scroll', () => widget.onFlow('scroll')),
                  ],
                  onPicked: () => setState(() => _open = null),
                ),
                _DropRow(
                  label: 'COLOR MODE',
                  value: themeLabel,
                  open: _open == 'theme',
                  onTap: () => _toggle('theme'),
                  options: [
                    for (final t in _themes)
                      _Choice(t.$2, p.theme == t.$1, () => widget.onTheme(t.$1), swatch: ReaderPalette.byName(t.$1).bg),
                  ],
                  onPicked: () => setState(() => _open = null),
                ),
                _DropRow(
                  label: 'FONT FACE',
                  value: readerFontLabel(p.fontFamily),
                  open: _open == 'font',
                  onTap: () => _toggle('font'),
                  options: [
                    for (final f in kReaderFonts)
                      _Choice(
                        f.note.isEmpty ? f.label : '${f.label}  ·  ${f.note}',
                        p.fontFamily == f.id,
                        () => widget.onFontFamily(f.id),
                      ),
                  ],
                  onPicked: () => setState(() => _open = null),
                ),
                _DropRow(
                  label: 'PAGE ANIMATION',
                  value: p.pageAnim == 'none' ? 'None (instant)' : 'Slide',
                  open: _open == 'anim',
                  onTap: () => _toggle('anim'),
                  options: [
                    _Choice('Slide', p.pageAnim != 'none', () => widget.onPageAnim('slide')),
                    _Choice('None (instant)', p.pageAnim == 'none', () => widget.onPageAnim('none')),
                  ],
                  onPicked: () => setState(() => _open = null),
                ),
                _StepRow(
                  label: 'FONT SIZE',
                  value: p.fontSize.round().toString(),
                  onMinus: () => widget.onFontSize(p.fontSize - 1),
                  onPlus: () => widget.onFontSize(p.fontSize + 1),
                ),
                _Row(
                  label: 'FONT THICKNESS',
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.amber400,
                          inactiveTrackColor: AppColors.borderLight,
                          thumbColor: AppColors.amber400,
                          overlayColor: AppColors.alpha(AppColors.amber400, 0x30),
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: weightIndex.toDouble(),
                          min: 0,
                          max: (kFontWeights.length - 1).toDouble(),
                          divisions: kFontWeights.length - 1,
                          onChanged: (v) => widget.onFontWeight(kFontWeights[v.round()]),
                        ),
                      ),
                      Text(
                        fontWeightLabel(p.fontWeight),
                        style: AppTypography.label(size: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                _StepRow(
                  label: 'LINE SPACING',
                  value: '${lineSpacingPercent(p.lineHeight)}%',
                  onMinus: () => widget.onLineHeight(double.parse((p.lineHeight - 0.1).toStringAsFixed(1))),
                  onPlus: () => widget.onLineHeight(double.parse((p.lineHeight + 0.1).toStringAsFixed(1))),
                ),
                _DropRow(
                  label: 'TEXT ALIGN',
                  value: alignLabel,
                  open: _open == 'align',
                  onTap: () => _toggle('align'),
                  options: [
                    for (final a in _aligns) _Choice(a.$2, _alignMode == a.$1, () => widget.onAlignMode(a.$1)),
                  ],
                  onPicked: () => setState(() => _open = null),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text('Page margins', style: AppTypography.label(size: 15))),
                      AppSwitch(value: p.margin >= 20, onChanged: widget.onMarginsOn),
                    ],
                  ),
                ),
                PressableOpacity(
                  pressedOpacity: 0.7,
                  semanticLabel: 'General settings',
                  onTap: widget.onGeneral,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'GENERAL SETTINGS',
                      textAlign: TextAlign.center,
                      style: AppTypography.label(size: 13, weight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice {
  const _Choice(this.label, this.selected, this.onSelect, {this.swatch});
  final String label;
  final bool selected;
  final VoidCallback onSelect;
  final Color? swatch;
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.label(size: 10.5, weight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      );
}

class _DropRow extends StatelessWidget {
  const _DropRow({
    required this.label,
    required this.value,
    required this.open,
    required this.onTap,
    required this.options,
    required this.onPicked,
  });

  final String label;
  final String value;
  final bool open;
  final VoidCallback onTap;
  final List<_Choice> options;
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) {
    return _Row(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PressableOpacity(
            pressedOpacity: 0.7,
            semanticLabel: label,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(value, style: AppTypography.label(size: 16))),
                  Icon(open ? Ionicons.chevron_up : Ionicons.chevron_down, size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          if (open) ...[
            const Divider(height: 8, color: AppColors.borderLight),
            for (final o in options)
              PressableOpacity(
                pressedOpacity: 0.7,
                onTap: () {
                  o.onSelect();
                  onPicked();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      if (o.swatch != null) ...[
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: o.swatch,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.borderLight),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          o.label,
                          style: AppTypography.label(
                            size: 15,
                            weight: o.selected ? FontWeight.w700 : FontWeight.w400,
                            color: o.selected ? AppColors.primary500 : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (o.selected) const Icon(Ionicons.checkmark_circle, size: 18, color: AppColors.primary500),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.value, required this.onMinus, required this.onPlus});
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, String l, VoidCallback t) => PressableOpacity(
          pressedOpacity: 0.6,
          semanticLabel: l,
          onTap: t,
          child: SizedBox(width: 48, height: 40, child: Icon(i, size: 30, color: AppColors.textPrimary)),
        );
    return _Row(
      label: label,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          btn(Ionicons.remove_circle_outline, 'Decrease $label', onMinus),
          Text(value, style: AppTypography.label(size: 18, weight: FontWeight.w600)),
          btn(Ionicons.add_circle_outline, 'Increase $label', onPlus),
        ],
      ),
    );
  }
}
