import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../annotations/data/annotation_models.dart';
import 'slide_panel.dart';

/// RN `AnnotationsList` (UI_SPEC §4.12) + a "Bookmarks" tab (Phase 9 addition).
/// Max 70 % of the screen height; bottom sheet, tap outside closes.
class AnnotationsSheet extends StatefulWidget {
  const AnnotationsSheet({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.annotations,
    required this.bookmarks,
    required this.showHighlightsTab,
    required this.onAnnotation,
    required this.onDeleteAnnotation,
    required this.onBookmark,
    required this.onDeleteBookmark,
    required this.onExport,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final List<Annotation> annotations;
  final List<Bookmark> bookmarks;

  /// PDFs have no text selection, so only the Bookmarks tab is shown.
  final bool showHighlightsTab;

  final ValueChanged<Annotation> onAnnotation;
  final ValueChanged<Annotation> onDeleteAnnotation;
  final ValueChanged<Bookmark> onBookmark;
  final ValueChanged<Bookmark> onDeleteBookmark;

  /// Export highlights & notes of this book (Markdown / text).
  final VoidCallback onExport;

  @override
  State<AnnotationsSheet> createState() => _AnnotationsSheetState();
}

class _AnnotationsSheetState extends State<AnnotationsSheet> {
  int _tab = 0; // 0 highlights, 1 bookmarks

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final tab = widget.showHighlightsTab ? _tab : 1;

    final title = tab == 0
        ? (widget.annotations.isNotEmpty
            ? 'Highlights & Notes (${widget.annotations.length})'
            : 'Highlights & Notes')
        : (widget.bookmarks.isNotEmpty
            ? 'Bookmarks (${widget.bookmarks.length})'
            : 'Bookmarks');

    return SlidePanel(
      isOpen: widget.isOpen,
      onClose: widget.onClose,
      edge: PanelEdge.bottom,
      showBackdrop: false,
      slideDistance: 500,
      child: Container(
        constraints: BoxConstraints(maxHeight: screenH * 0.7),
        padding: EdgeInsets.only(bottom: bottom + 16),
        decoration: const BoxDecoration(
          color: AppColors.elevated,
          border: Border(top: BorderSide(color: AppColors.borderLight)),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(title, style: AppTypography.label(size: 16, weight: FontWeight.w600)),
                      ),
                      if (widget.annotations.isNotEmpty) ...[
                        PressableOpacity(
                          pressedOpacity: 0.7,
                          semanticLabel: 'Export notes',
                          onTap: widget.onExport,
                          child: Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Ionicons.share_outline, size: 18, color: AppColors.primary500),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      PressableOpacity(
                        pressedOpacity: 0.7,
                        onTap: widget.onClose,
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Ionicons.close,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.showHighlightsTab) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Tab(
                          label: 'Highlights',
                          active: _tab == 0,
                          onTap: () => setState(() => _tab = 0),
                        ),
                        const SizedBox(width: 8),
                        _Tab(
                          label: 'Bookmarks',
                          active: _tab == 1,
                          onTap: () => setState(() => _tab = 1),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Flexible(child: tab == 0 ? _highlights() : _bookmarks()),
          ],
        ),
      ),
    );
  }

  Widget _empty(IconData icon, String title, String desc) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(title, style: AppTypography.label(size: 16, weight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: AppTypography.label(
                size: 13,
                color: AppColors.textSecondary,
                lineHeight: 19,
              ),
            ),
          ],
        ),
      );

  Widget _highlights() {
    if (widget.annotations.isEmpty) {
      return _empty(
        Ionicons.bookmark_outline,
        'No highlights yet',
        'Select text while reading to highlight or add notes.',
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: widget.annotations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = widget.annotations[i];
        return _AnnotationItem(
          item: a,
          onTap: () => widget.onAnnotation(a),
          onDelete: () => widget.onDeleteAnnotation(a),
        );
      },
    );
  }

  Widget _bookmarks() {
    if (widget.bookmarks.isEmpty) {
      return _empty(
        Ionicons.bookmark_outline,
        'No bookmarks yet',
        'Tap the bookmark button in the top bar to save the page you are on.',
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: widget.bookmarks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final b = widget.bookmarks[i];
        return _BookmarkItem(
          item: b,
          onTap: () => widget.onBookmark(b),
          onDelete: () => widget.onDeleteBookmark(b),
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableOpacity(
      pressedOpacity: 0.75,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.alpha(AppColors.primary500, 0x15) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.primary500 : AppColors.borderDefault,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label(
            size: 13,
            weight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? AppColors.primary500 : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AnnotationItem extends StatelessWidget {
  const _AnnotationItem({required this.item, required this.onTap, required this.onDelete});

  final Annotation item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PressableOpacity(
      pressedOpacity: 0.75,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                constraints: const BoxConstraints(minHeight: 40),
                decoration: BoxDecoration(
                  color: item.color.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.selectedText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label(
                        size: 13,
                        lineHeight: 19,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (item.hasNote) ...[
                      const SizedBox(height: 5 + 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Ionicons.create_outline,
                              size: 12,
                              color: AppColors.primary500,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item.note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label(
                                size: 12,
                                color: AppColors.textSecondary,
                                lineHeight: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 5 + 2),
                    Text(
                      item.chapterTitle,
                      style: AppTypography.label(size: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Ionicons.trash_outline, size: 15, color: AppColors.error500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarkItem extends StatelessWidget {
  const _BookmarkItem({required this.item, required this.onTap, required this.onDelete});

  final Bookmark item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final label = item.label.isNotEmpty
        ? item.label
        : (item.chapterTitle.isNotEmpty ? item.chapterTitle : 'Bookmarked page');
    return PressableOpacity(
      pressedOpacity: 0.75,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Row(
          children: [
            const Icon(Ionicons.bookmark, size: 16, color: AppColors.primary500),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(size: 13, lineHeight: 19),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.percentage.round()}%',
                    style: AppTypography.label(size: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Ionicons.trash_outline, size: 15, color: AppColors.error500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
