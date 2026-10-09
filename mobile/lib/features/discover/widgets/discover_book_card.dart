import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../library/widgets/book_cover.dart';
import '../data/gutenberg_models.dart';

/// RN `DiscoverBookCard` (UI_SPEC §4.9). RN hard-codes width 130 (three of
/// them overflow a phone); here the width comes from the grid and the cover
/// keeps the 130 : 170 ratio.
class DiscoverBookCard extends StatelessWidget {
  const DiscoverBookCard({
    super.key,
    required this.book,
    required this.width,
    required this.onTap,
    this.isInLibrary = false,
  });

  final GutenbergBook book;
  final double width;
  final VoidCallback onTap;
  final bool isInLibrary;

  /// Height of everything under the cover (8 gap + 2-line title + author +
  /// meta rows), used by the grid for `mainAxisExtent`.
  static const double infoHeight = 80;

  static double coverHeightFor(double width) => width * 170 / 130;

  @override
  Widget build(BuildContext context) {
    final authors = authorsLine(book, max: 2);

    return PressableOpacity(
      pressedOpacity: 0.78,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                BookCover(
                  title: book.title,
                  coverUrl: coverUrl(book.formats, book.id),
                  width: width,
                  height: coverHeightFor(width),
                  radius: 10,
                  showGlow: false,
                  showIcon: false,
                  fillAlpha: 0x20,
                ),
                if (isInLibrary)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.success500,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Ionicons.checkmark,
                        size: 10,
                        color: AppColors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label(
                size: 12,
                weight: FontWeight.w600,
                lineHeight: 17,
              ),
            ),
            if (authors.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                authors,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(
                  size: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Ionicons.cloud_download_outline,
                  size: 11,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 3),
                Text(
                  downloadsK(book.downloadCount),
                  style: AppTypography.label(
                    size: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
