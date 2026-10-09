import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/pressable_opacity.dart';
import '../data/models/book.dart';
import 'book_cover.dart';

enum BookCardSize { sm, md, lg }

class _Cfg {
  const _Cfg(this.width, this.coverHeight, this.titleSize, this.authorSize,
      this.padding, this.radius);
  final double? width; // null = fill
  final double coverHeight;
  final double titleSize;
  final double authorSize;
  final double padding;
  final double radius;
}

const Map<BookCardSize, _Cfg> _cfg = {
  BookCardSize.sm: _Cfg(120, 156, 12, 11, 8, 10),
  BookCardSize.md: _Cfg(null, 180, 13, 12, 10, 12),
  BookCardSize.lg: _Cfg(null, 220, 15, 13, 12, 14),
};

/// RN `BookCard` (UI_SPEC §4.6). No converting badge (conversion is on hold).
class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    this.size = BookCardSize.md,
    required this.onTap,
    this.onLongPress,
  });

  final Book book;
  final BookCardSize size;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = _cfg[size]!;
    final progress = book.progress;
    final hasProgress = progress != null && progress.percentage > 0;

    return PressableOpacity(
      pressedOpacity: 0.78,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: c.width,
        padding: EdgeInsets.all(c.padding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(c.radius),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                BookCover(
                  title: book.title,
                  coverUrl: book.coverUrl,
                  height: c.coverHeight,
                  radius: c.radius - 2,
                ),
                if (progress?.isCompleted == true)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Ionicons.checkmark_circle,
                        size: 20,
                        color: AppColors.success500,
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
                size: c.titleSize,
                weight: FontWeight.w600,
                lineHeight: 18,
              ),
            ),
            if (book.author.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(
                  size: c.authorSize,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (size == BookCardSize.sm && book.fileSize > 0) ...[
              const SizedBox(height: 3 + 2),
              Text(
                formatFileSize(book.fileSize),
                style: AppTypography.label(size: 10, color: AppColors.textMuted),
              ),
            ],
            if (hasProgress) ...[
              const SizedBox(height: 8),
              ProgressTrack(
                percentage: progress.percentage,
                height: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Track (borderLight) + fill (primary500), rounded 2.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.percentage,
    required this.height,
  });

  final double percentage;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = (percentage / 100).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: height,
        color: AppColors.borderLight,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: f,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary500,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
