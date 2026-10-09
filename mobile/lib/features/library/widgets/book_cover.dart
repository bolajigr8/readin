import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/book_visuals.dart';

/// RN `CoverFallback`: colour@14.5% fill, 1 px colour@25% border, 60 % × 60 %
/// glow (colour@19%) in the middle, bold initials and (optionally) a faint
/// book icon.
class CoverFallback extends StatelessWidget {
  const CoverFallback({
    super.key,
    required this.title,
    this.width,
    required this.height,
    required this.radius,
    this.initialsSize = 28,
    this.showIcon = true,
    this.showGlow = true,
    this.fillAlpha = 0x25,
    this.initials,
  });

  final String title;
  final double? width;
  final double height;
  final double radius;
  final double initialsSize;
  final bool showIcon;
  final bool showGlow;

  /// Hex alpha of the fill (RN: book cards `25`, discover cards `20`).
  final int fillAlpha;

  /// Overrides the computed initials (book detail uses the first 2 letters).
  final String? initials;

  @override
  Widget build(BuildContext context) {
    final color = coverColor(title);

    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.alpha(color, fillAlpha),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.alpha(color, 0x40)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showGlow)
            FractionallySizedBox(
              widthFactor: 0.6,
              heightFactor: 0.6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.alpha(color, 0x30),
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                initials ?? titleInitials(title),
                style: AppTypography.label(
                  size: initialsSize,
                  weight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (showIcon) ...[
                const SizedBox(height: 6),
                Icon(
                  Ionicons.book_outline,
                  size: 20,
                  color: AppColors.alpha(color, 0x60),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Network cover (`cover` fit, rounded) with the fallback when there is no
/// URL or the image fails to load.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.title,
    required this.coverUrl,
    this.width,
    required this.height,
    required this.radius,
    this.initialsSize = 28,
    this.showIcon = true,
    this.showGlow = true,
    this.fillAlpha = 0x25,
    this.initials,
  });

  final String title;
  final String coverUrl;
  final double? width;
  final double height;
  final double radius;
  final double initialsSize;
  final bool showIcon;
  final bool showGlow;
  final int fillAlpha;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => CoverFallback(
          title: title,
          width: width,
          height: height,
          radius: radius,
          initialsSize: initialsSize,
          showIcon: showIcon,
          showGlow: showGlow,
          fillAlpha: fillAlpha,
          initials: initials,
        );

    if (coverUrl.isEmpty) return fallback();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: coverUrl,
        width: width ?? double.infinity,
        height: height,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, _) => Container(
          width: width ?? double.infinity,
          height: height,
          color: AppColors.surface,
        ),
        errorWidget: (_, _, _) => fallback(),
      ),
    );
  }
}
