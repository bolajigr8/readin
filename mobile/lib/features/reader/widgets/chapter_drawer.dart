import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/pressable_opacity.dart';
import '../data/reader_models.dart';
import 'slide_panel.dart';

/// RN `ChapterDrawer` (UI_SPEC §4.12) + in-book search: left panel
/// `min(78 %, 300)`, search field, "Table of Contents" with nested items
/// (indent 16 / level, active top-level chapter highlighted) or the search
/// results. Selecting an item navigates and closes.
class ChapterDrawer extends StatefulWidget {
  const ChapterDrawer({
    super.key,
    required this.toc,
    required this.currentChapter,
    required this.isOpen,
    required this.onClose,
    required this.onSelect,
    required this.searchQuery,
    required this.searchResults,
    required this.isSearching,
    required this.onSearch,
    required this.onClearSearch,
    required this.onResult,
  });

  final List<TocItem> toc;
  final int currentChapter;
  final bool isOpen;
  final VoidCallback onClose;

  /// Called with the entry's href.
  final void Function(String href) onSelect;

  final String searchQuery;
  final List<SearchHit> searchResults;
  final bool isSearching;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<SearchHit> onResult;

  @override
  State<ChapterDrawer> createState() => _ChapterDrawerState();
}

class _ChapterDrawerState extends State<ChapterDrawer> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _clear() {
    _ctrl.clear();
    widget.onClearSearch();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width * 0.78, 300.0);
    final insets = MediaQuery.viewPaddingOf(context);
    final searching = widget.searchQuery.isNotEmpty;

    return SlidePanel(
      isOpen: widget.isOpen,
      onClose: widget.onClose,
      edge: PanelEdge.left,
      size: width,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(right: BorderSide(color: AppColors.borderDefault)),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, insets.top + 12, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    searching ? 'Search' : 'Table of Contents',
                    style: AppTypography.section17.copyWith(fontSize: 16),
                  ),
                  PressableOpacity(
                    pressedOpacity: 0.7,
                    semanticLabel: 'Close',
                    onTap: widget.onClose,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
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
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Row(
                  children: [
                    const Icon(Ionicons.search_outline, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        textInputAction: TextInputAction.search,
                        autocorrect: false,
                        cursorColor: AppColors.primary500,
                        style: AppTypography.label(size: 14),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: widget.onSearch,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Search in book...',
                          hintStyle: AppTypography.label(size: 14, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    if (_ctrl.text.isNotEmpty)
                      PressableOpacity(
                        pressedOpacity: 0.7,
                        semanticLabel: 'Clear search',
                        onTap: _clear,
                        child: const Icon(
                          Ionicons.close_circle,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 1,
                width: double.infinity,
                child: ColoredBox(color: AppColors.borderDefault),
              ),
            ),
            Expanded(
              child: searching
                  ? _results(insets)
                  : (widget.toc.isEmpty
                      ? Center(
                          child: Text(
                            'No chapters found',
                            style: AppTypography.label(size: 14, color: AppColors.textMuted),
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.only(bottom: insets.bottom + 16),
                          children: [
                            for (var i = 0; i < widget.toc.length; i++)
                              ..._rows(widget.toc[i], 0, i),
                          ],
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(EdgeInsets insets) {
    if (widget.isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary500),
            ),
            const SizedBox(height: 10),
            Text(
              'Searching the book...',
              style: AppTypography.label(size: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }
    if (widget.searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'No results for "${widget.searchQuery}"',
            textAlign: TextAlign.center,
            style: AppTypography.label(size: 14, color: AppColors.textMuted),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(0, 8, 0, insets.bottom + 16),
      itemCount: widget.searchResults.length,
      separatorBuilder: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 1,
          child: ColoredBox(color: AppColors.borderDefault),
        ),
      ),
      itemBuilder: (context, i) {
        final hit = widget.searchResults[i];
        return PressableOpacity(
          pressedOpacity: 0.7,
          onTap: () {
            widget.onResult(hit);
            widget.onClose();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: _highlighted(hit.excerpt, widget.searchQuery),
          ),
        );
      },
    );
  }

  /// Excerpt with every occurrence of [query] in bold orange.
  Widget _highlighted(String text, String query) {
    final base = AppTypography.label(
      size: 13,
      color: AppColors.textSecondary,
      lineHeight: 19,
    );
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final spans = <TextSpan>[];
    var from = 0;
    while (q.isNotEmpty) {
      final i = lower.indexOf(q, from);
      if (i < 0) break;
      if (i > from) spans.add(TextSpan(text: text.substring(from, i)));
      spans.add(
        TextSpan(
          text: text.substring(i, i + q.length),
          style: base.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary500),
        ),
      );
      from = i + q.length;
    }
    if (from < text.length) spans.add(TextSpan(text: text.substring(from)));
    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<Widget> _rows(TocItem item, int depth, int topIndex) {
    final active = depth == 0 && topIndex == widget.currentChapter;
    return [
      PressableOpacity(
        pressedOpacity: 0.7,
        onTap: () {
          widget.onSelect(item.href);
          widget.onClose();
        },
        child: Container(
          color: active ? AppColors.alpha(AppColors.primary500, 0x10) : null,
          child: Stack(
            children: [
              if (active)
                const Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  width: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary500,
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(3)),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.0 + depth * 16, 13, 20, 13),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(
                      size: 14,
                      lineHeight: 20,
                      weight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? AppColors.primary500 : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      for (final s in item.subitems) ..._rows(s, depth + 1, topIndex),
    ];
  }
}
