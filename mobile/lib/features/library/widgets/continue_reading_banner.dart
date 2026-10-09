import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/pressable_opacity.dart';
import '../data/models/book.dart';
import 'book_card.dart';
import 'book_cover.dart';

/// RN `ContinueReadingBanner` (UI_SPEC §4.7).
class ContinueReadingBanner extends StatelessWidget {
  const ContinueReadingBanner({
    super.key,
    required this.book,
    required this.onTap,
  });

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = book.percentage;

    return PressableOpacity(
      pressedOpacity: 0.8,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.alpha(AppColors.primary500, 0x30)),
        ),
        child: Row(
          children: [
            BookCover(
              title: book.title,
              coverUrl: book.coverUrl,
              width: 68,
              height: 88,
              radius: 8,
              initialsSize: 18,
              showIcon: false,
              showGlow: false,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Ionicons.book_outline,
                        size: 11,
                        color: AppColors.primary500,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'CONTINUE READING',
                        style: AppTypography.label(
                          size: 11,
                          weight: FontWeight.w500,
                          letterSpacing: 0.5,
                          color: AppColors.primary500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2 + 5),
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(
                      size: 15,
                      weight: FontWeight.w600,
                      lineHeight: 20,
                    ),
                  ),
                  if (book.author.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label(
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5 + 4),
                  Row(
                    children: [
                      Expanded(
                        child: ProgressTrack(percentage: pct, height: 4),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${pct.round()}%',
                          textAlign: TextAlign.right,
                          style: AppTypography.label(
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppColors.primary500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            const Icon(
              Ionicons.chevron_forward,
              size: 18,
              color: AppColors.primary500,
            ),
          ],
        ),
      ),
    );
  }
}
