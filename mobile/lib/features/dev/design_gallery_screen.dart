import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../constants/app_colors.dart';
import '../../core/widgets/app_loader.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../utils/book_visuals.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/buttons.dart';
import '../../widgets/empty_state.dart';

/// Dev-only screen to eyeball parity against the RN app (tokens, type,
/// buttons, inputs, empty state, toasts). Remove before release.
class DesignGalleryScreen extends StatelessWidget {
  const DesignGalleryScreen({super.key});

  static const _swatches = <(String, Color)>[
    ('background', AppColors.background),
    ('surface', AppColors.surface),
    ('elevated', AppColors.elevated),
    ('border.default', AppColors.borderDefault),
    ('border.light', AppColors.borderLight),
    ('text.primary', AppColors.textPrimary),
    ('text.secondary', AppColors.textSecondary),
    ('text.muted', AppColors.textMuted),
    ('primary300', AppColors.primary300),
    ('primary400', AppColors.primary400),
    ('primary500', AppColors.primary500),
    ('primary600', AppColors.primary600),
    ('primary700', AppColors.primary700),
    ('amber400', AppColors.amber400),
    ('amber500', AppColors.amber500),
    ('amber600', AppColors.amber600),
    ('success400', AppColors.success400),
    ('success500', AppColors.success500),
    ('success600', AppColors.success600),
    ('error400', AppColors.error400),
    ('error500', AppColors.error500),
    ('error600', AppColors.error600),
    ('hl yellow', AppColors.highlightYellow),
    ('hl green', AppColors.highlightGreen),
    ('hl blue', AppColors.highlightBlue),
    ('hl pink', AppColors.highlightPink),
    ('hl purple', AppColors.highlightPurple),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.customColors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Design gallery', style: AppTypography.h1),
            const SizedBox(height: 4),
            Text(
              'Dev only — compare with the RN app.',
              style: AppTypography.label(
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
            _section('Colours'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final s in _swatches) _Swatch(s.$1, s.$2)],
            ),
            _section('Alpha helper (RN color + "25")'),
            Row(
              children: [
                for (final a in const [0x10, 0x18, 0x25, 0x40, 0x80])
                  Expanded(
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.only(right: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.alpha(AppColors.primary500, a),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        a.toRadixString(16).toUpperCase(),
                        style: AppTypography.micro11,
                      ),
                    ),
                  ),
              ],
            ),
            _section('Typography (Inter)'),
            Text('h1 36/700 Read More', style: AppTypography.h1),
            Text('title22 22/600', style: AppTypography.title22),
            Text('title20 20/600', style: AppTypography.title20),
            Text('section17 17/600', style: AppTypography.section17),
            Text('body16 16/400', style: AppTypography.body16),
            Text('body15 15/400', style: AppTypography.body15),
            Text('body14 14/400', style: AppTypography.body14),
            Text('caption13 13/400', style: AppTypography.caption13),
            Text('caption12 12/400', style: AppTypography.caption12),
            Text('micro11 11/400', style: AppTypography.micro11),
            Text('micro10 10/400', style: AppTypography.micro10),
            _section('Cover fallback colours'),
            Row(
              children: [
                for (final t in const [
                  'Pride and Prejudice',
                  'Frankenstein',
                  'Dracula',
                  'Emma',
                  'Moby Dick',
                ])
                  Expanded(child: _CoverChip(t)),
              ],
            ),
            _section('Buttons'),
            const _ButtonRows(),
            _section('Inputs'),
            const AppTextField(
              label: 'Email',
              hint: 'you@example.com',
              leftIcon: Ionicons.mail_outline,
            ),
            const SizedBox(height: 16),
            const AppTextField(
              label: 'Password',
              hint: '••••••••',
              leftIcon: Ionicons.lock_closed_outline,
              isPassword: true,
            ),
            const SizedBox(height: 16),
            const AppTextField(
              label: 'With error',
              hint: 'Name',
              leftIcon: Ionicons.person_outline,
              error: 'Name is required',
            ),
            _section('Empty state'),
            EmptyState(
              icon: Ionicons.library_outline,
              title: 'Your library is empty',
              description:
                  'Import a PDF or EPUB, or discover a free classic to get started.',
              actionLabel: 'Import a Book',
              onAction: () {},
            ),
            _section('Loader'),
            const SizedBox(height: 120, child: AppLoader(label: 'Loading...')),
            _section('Toasts'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  label: 'Success',
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => AppToast.success('"Dracula" added to your library!'),
                ),
                AppButton(
                  label: 'Error',
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => AppToast.error('Could not add book. Check your connection.'),
                ),
                AppButton(
                  label: 'Warning',
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => AppToast.warning('Table of contents not available for PDFs.'),
                ),
                AppButton(
                  label: 'Info',
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => AppToast.info('Highlighted!'),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Text(
          title.toUpperCase(),
          style: AppTypography.label(
            size: 11,
            weight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hex =
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return SizedBox(
      width: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderDefault),
            ),
          ),
          const SizedBox(height: 4),
          Text(name, style: AppTypography.micro10),
          Text(
            hex,
            style: AppTypography.label(size: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _CoverChip extends StatelessWidget {
  const _CoverChip(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final color = coverColor(title);
    return Container(
      height: 64,
      margin: const EdgeInsets.only(right: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.alpha(color, 0x25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.alpha(color, 0x40)),
      ),
      child: Text(
        titleInitials(title),
        style: AppTypography.label(
          size: 18,
          weight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ButtonRows extends StatelessWidget {
  const _ButtonRows();

  @override
  Widget build(BuildContext context) {
    Widget row(AppButtonVariant v) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppButton(label: 'Small', variant: v, size: AppButtonSize.sm, onPressed: () {}),
              AppButton(label: 'Medium', variant: v, onPressed: () {}),
              AppButton(label: 'Large', variant: v, size: AppButtonSize.lg, onPressed: () {}),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(AppButtonVariant.primary),
        row(AppButtonVariant.secondary),
        row(AppButtonVariant.outline),
        row(AppButtonVariant.ghost),
        AppButton(
          label: 'Sign In',
          size: AppButtonSize.lg,
          expand: true,
          loading: true,
          onPressed: () {},
        ),
        const SizedBox(height: 10),
        const AppButton(label: 'Disabled', expand: true),
      ],
    );
  }
}
