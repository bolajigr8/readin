import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_typography.dart';
import 'onboarding_slides.dart';

/// A single slide: hero (flex .55) + content (flex .45).
class OnboardingSlideView extends StatelessWidget {
  const OnboardingSlideView({super.key, required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(flex: 55, child: _Hero(slide: slide)),
        Expanded(flex: 45, child: _Content(slide: slide)),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.slide});

  final OnboardingSlide slide;

  // (top %, left %, right %, size) — RN FloatingDots.
  static const _dots = <({double top, double? left, double? right, double size})>[
    (top: 0.12, left: 0.08, right: null, size: 4),
    (top: 0.25, left: null, right: 0.10, size: 6),
    (top: 0.08, left: null, right: 0.25, size: 3),
    (top: 0.35, left: 0.15, right: null, size: 5),
    (top: 0.18, left: 0.40, right: null, size: 4),
  ];

  @override
  Widget build(BuildContext context) {
    final color = slide.color;

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;

        Widget glow(double d, int alpha) => Positioned(
              left: w / 2 - d / 2,
              top: h / 2 - d / 2,
              width: d,
              height: d,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.alpha(color, alpha),
                ),
              ),
            );

        return ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              glow(300, 0x08),
              glow(210, 0x12),
              glow(130, 0x1E),
              for (final d in _dots)
                Positioned(
                  top: h * d.top,
                  left: d.left == null ? null : w * d.left!,
                  right: d.right == null ? null : w * d.right!,
                  width: d.size,
                  height: d.size,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.alpha(color, 0x40),
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.alpha(color, 0x15),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: AppColors.alpha(color, 0x30)),
                      ),
                      child: Container(
                        width: 82,
                        height: 82,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.alpha(color, 0x25),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Icon(slide.icon, size: 38, color: color),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 1,
                          color: AppColors.alpha(color, 0x30),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 44,
                          height: 1,
                          color: AppColors.alpha(color, 0x30),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final color = slide.color;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.alpha(color, 0x20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.alpha(color, 0x40)),
            ),
            child: Text(
              slide.badge.toUpperCase(),
              style: AppTypography.label(
                size: 12,
                weight: FontWeight.w600,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            slide.headline,
            style: AppTypography.label(
              size: 36,
              weight: FontWeight.w700,
              lineHeight: 44,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            slide.description,
            style: AppTypography.label(
              size: 15,
              color: AppColors.textSecondary,
              lineHeight: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '✦ ${slide.caption}',
            style: AppTypography.label(
              size: 13,
              weight: FontWeight.w500,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
