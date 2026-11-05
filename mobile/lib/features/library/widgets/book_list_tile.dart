import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../core/formats.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../shelves/shelf_models.dart';
import '../../shelves/shelf_providers.dart';
import '../data/models/book.dart';
import 'book_cover.dart';

/// List row copied from a well-loved reader: cover on the left; title, author
/// and "FORMAT, size" on the right; a thin progress line with a dot; and a row
/// of quick actions (★ favourite · 🕘 want to read · ✓✓ finished · shelves · ⋮).
class BookListTile extends ConsumerWidget {
  const BookListTile({
    super.key,
    required this.book,
    required this.onTap,
    required this.onMore,
  });

  final Book book;
  final VoidCallback onTap;

  /// Shelves / status / delete sheet.
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(shelvesProvider);
    final ctl = ref.read(shelvesProvider.notifier);
    final status = effectiveStatus(book, data);
    final fav = data.favorites.contains(book.id);
    final pct = (book.progress?.percentage ?? 0).clamp(0.0, 100.0).toDouble();
    final isDoc = book.kind != ViewerKind.epub && book.kind != ViewerKind.pdf;
    final sub = [
      labelOfFormat(book.format).toUpperCase().split(' ').first,
      if (book.fileSize > 0) formatFileSize(book.fileSize),
    ].join(', ');

    Widget action(IconData icon, bool active, String label, VoidCallback t) => PressableOpacity(
          pressedOpacity: 0.7,
          semanticLabel: label,
          onTap: t,
          child: SizedBox(
            width: 44,
            height: 40,
            child: Icon(icon, size: 24, color: active ? AppColors.primary500 : AppColors.textMuted),
          ),
        );

    return PressableOpacity(
      pressedOpacity: 0.85,
      onTap: onTap,
      onLongPress: onMore,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: BookCover(
                title: book.title,
                coverUrl: book.coverUrl,
                width: 92,
                height: 128,
                radius: 6,
                bookId: book.id,
                badge: isDoc ? labelOfFormat(book.format) : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 128,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label(size: 16, weight: FontWeight.w600, lineHeight: 21),
                    ),
                    if (book.author.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label(size: 13, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label(size: 12, color: AppColors.textMuted),
                    ),
                    const Spacer(),
                    // progress line with a dot
                    SizedBox(
                      height: 14,
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final x = box.maxWidth * pct / 100;
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Container(height: 1.5, color: AppColors.borderLight),
                              Container(height: 1.5, width: x, color: AppColors.primary500),
                              Positioned(
                                left: (x - 4).clamp(0.0, box.maxWidth - 8).toDouble(),
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: pct > 0 ? AppColors.primary500 : AppColors.borderLight,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        action(
                          fav ? Ionicons.star : Ionicons.star_outline,
                          fav,
                          'Favourite',
                          () => ctl.toggleFavorite(book.id),
                        ),
                        action(
                          Ionicons.time_outline,
                          status == ReadStatus.want,
                          'Want to read',
                          () => ctl.setStatus(book, status == ReadStatus.want ? ReadStatus.none : ReadStatus.want),
                        ),
                        action(
                          Ionicons.checkmark_done_outline,
                          status == ReadStatus.finished,
                          'Finished',
                          () => ctl.setStatus(
                            book,
                            status == ReadStatus.finished ? ReadStatus.none : ReadStatus.finished,
                          ),
                        ),
                        action(Ionicons.library_outline, false, 'Shelves', onMore),
                        action(Ionicons.ellipsis_vertical, false, 'More', onMore),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
