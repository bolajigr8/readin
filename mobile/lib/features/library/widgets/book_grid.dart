import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../data/models/book.dart';
import 'book_card.dart';

/// RN `BookGrid`: 2-column (width `(w − 32 − 12) / 2`) or 1-column list of
/// `md` cards, 12 px gaps, 16 px side padding, pull-to-refresh, empty slot.
/// Rows are laid out manually so cards keep their natural height and align to
/// the top like RN (a fixed-extent grid would clip long titles).
class BookGrid extends StatelessWidget {
  const BookGrid({
    super.key,
    required this.books,
    this.columns = 2,
    required this.onBookTap,
    this.onBookLongPress,
    this.onRefresh,
    this.header,
    this.empty,
  });

  final List<Book> books;
  final int columns;
  final void Function(Book book) onBookTap;
  final void Function(Book book)? onBookLongPress;
  final Future<void> Function()? onRefresh;
  final Widget? header;
  final Widget? empty;

  static const double _hPad = 16;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final cols = columns == 1 ? 1 : 2;
    final rowCount = (books.length / cols).ceil();

    Widget card(Book b) => BookCard(
          book: b,
          onTap: () => onBookTap(b),
          onLongPress:
              onBookLongPress == null ? null : () => onBookLongPress!(b),
        );

    final scroll = LayoutBuilder(
      builder: (context, box) {
        final cardWidth = cols == 2
            ? (box.maxWidth - _hPad * 2 - _gap) / 2
            : box.maxWidth - _hPad * 2;

        return CustomScrollView(
          // Always scrollable so pull-to-refresh works on short lists.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (header != null) SliverToBoxAdapter(child: header),
            if (books.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: empty ?? const SizedBox.shrink(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_hPad, 0, _hPad, 24),
                sliver: SliverList.separated(
                  itemCount: rowCount,
                  separatorBuilder: (_, _) => const SizedBox(height: _gap),
                  itemBuilder: (context, row) {
                    final first = row * cols;
                    final a = books[first];
                    final b = cols == 2 && first + 1 < books.length
                        ? books[first + 1]
                        : null;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: cardWidth, child: card(a)),
                        if (cols == 2) ...[
                          const SizedBox(width: _gap),
                          SizedBox(
                            width: cardWidth,
                            child: b == null ? null : card(b),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
          ],
        );
      },
    );

    if (onRefresh == null) return scroll;
    return RefreshIndicator(
      color: AppColors.primary500,
      backgroundColor: AppColors.white,
      onRefresh: onRefresh!,
      child: scroll,
    );
  }
}
