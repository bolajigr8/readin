import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/book_visuals.dart';
import '../providers/library_providers.dart';

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
    this.badge,
  });

  /// Small label at the bottom ("DOCX", "XLSX"…) for books without a cover image.
  final String? badge;

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
          if (badge != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: AppTypography.label(size: 10, weight: FontWeight.w700, color: AppColors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Network cover (`cover` fit, rounded) with the fallback when there is no
/// URL or the image fails to load.
class BookCover extends ConsumerWidget {
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
    this.bookId,
    this.badge,
  });

  /// When set, a cover image stored on the phone (from the EPUB) is used first.
  final String? bookId;
  final String? badge;

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
  Widget build(BuildContext context, WidgetRef ref) {
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
          badge: badge,
        );

    final id = bookId;
    if (id != null) {
      final file = ref.watch(bookCoverProvider(id)).valueOrNull;
      if (file != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.file(
            file,
            width: width ?? double.infinity,
            height: height,
            fit: BoxFit.cover,
            cacheWidth: 420, // decode a small bitmap, not the 2 MB original
            errorBuilder: (_, _, _) => fallback(),
          ),
        );
      }
    }

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
