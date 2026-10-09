import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../core/services/routes.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_spinner.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../library/providers/library_providers.dart';
import '../data/gutenberg_models.dart';
import '../providers/discover_providers.dart';
import '../widgets/discover_book_card.dart';

/// UI_SPEC §4.9 — Discover tab (Project Gutenberg via Gutendex).
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _lastNextErrorShown = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 400 ms debounce; fewer than 2 characters = not searching.
  void _onSearchChanged(String text) {
    setState(() {}); // refresh the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final q = text.trim();
      ref.read(discoverSearchProvider.notifier).state = q.length >= 2 ? q : '';
      if (q.length >= 2) ref.read(discoverCategoryProvider.notifier).state = null;
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    ref.read(discoverSearchProvider.notifier).state = '';
    setState(() {});
  }

  void _toggleCategory(String id) {
    final current = ref.read(discoverCategoryProvider);
    if (current == id) {
      ref.read(discoverCategoryProvider.notifier).state = null;
    } else {
      ref.read(discoverCategoryProvider.notifier).state = id;
      _debounce?.cancel();
      _searchCtrl.clear();
      ref.read(discoverSearchProvider.notifier).state = '';
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(discoverActiveQueryProvider);
    final feed = ref.watch(discoverFeedProvider(query));
    final inLibrary = ref.watch(libraryGutenbergIdsProvider);
    final category = ref.watch(discoverCategoryProvider);
    final searchText = ref.watch(discoverSearchProvider);
    final isSearching = query.kind == DiscoverKind.search;

    // Toast once when "load more" fails.
    ref.listen(discoverFeedProvider(query), (prev, next) {
      final e = next.nextError;
      if (e != null && e.message != _lastNextErrorShown) {
        _lastNextErrorShown = e.message;
        AppToast.error('Could not load more books.');
      } else if (e == null) {
        _lastNextErrorShown = '';
      }
    });

    final title = isSearching
        ? 'Results for "${query.value}"'
        : category != null
            ? kDiscoverCategories.firstWhere((c) => c.id == category).label
            : 'Most Popular';

    Widget body;
    if (feed.isLoading) {
      body = const LoadingSpinner(fullScreen: true, label: 'Loading books...');
    } else if (feed.error != null) {
      body = Center(
        child: EmptyState(
          icon: Ionicons.wifi_outline,
          title: 'Could not load books',
          description:
              'Check your internet connection. Gutenberg requires internet access.',
          actionLabel: 'Try Again',
          onAction: () =>
              ref.read(discoverFeedProvider(query).notifier).loadFirst(),
        ),
      );
    } else if (feed.books.isEmpty) {
      body = Center(
        child: EmptyState(
          icon: Ionicons.search_outline,
          title: 'No books found',
          description: 'No results for "$searchText". Try a different search.',
        ),
      );
    } else {
      body = _Grid(
        query: query,
        feed: feed,
        inLibrary: inLibrary,
      );
    }

    return Column(
      children: [
        const AppHeader(
          title: 'Discover',
          rightContent: Icon(
            Ionicons.library_outline,
            size: 22,
            color: AppColors.textSecondary,
          ),
        ),

        // Search bar
        Container(
          margin: const EdgeInsets.only(left: 16, right: 16, top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            children: [
              const Icon(
                Ionicons.search_outline,
                size: 17,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.search,
                  cursorColor: AppColors.primary500,
                  style: AppTypography.body15,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Search 70,000+ free books...',
                    hintStyle: AppTypography.label(
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              if (_searchCtrl.text.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _clearSearch,
                  child: const Icon(
                    Ionicons.close_circle,
                    size: 17,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Category chips (hidden while searching). Natural height like RN's
        // horizontal FlatList: padding 12/16, gap 8.
        if (!isSearching)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                for (var i = 0; i < kDiscoverCategories.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _CategoryChip(
                    category: kDiscoverCategories[i],
                    active: category == kDiscoverCategories[i].id,
                    onTap: () => _toggleCategory(kDiscoverCategories[i].id),
                  ),
                ],
              ],
            ),
          ),

        // Section header
        Padding(
          // RN has no top padding; with the chips hidden the title would touch the
          // search bar, so searching gets 12 px (same as the chips' padding).
          padding: EdgeInsets.fromLTRB(16, isSearching ? 12 : 0, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label(size: 16, weight: FontWeight.w600),
                ),
              ),
              if (!feed.isLoading && feed.error == null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    '${NumberFormat.decimalPattern().format(feed.count)} books',
                    style: AppTypography.label(
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),

        Expanded(child: body),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.active,
    required this.onTap,
  });

  final DiscoverCategory category;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableOpacity(
      pressedOpacity: 0.75,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppColors.alpha(AppColors.primary500, 0x20)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.alpha(AppColors.primary500, 0x60)
                : AppColors.borderDefault,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(
              category.label,
              style: AppTypography.label(
                size: 13,
                weight: FontWeight.w500,
                color: active ? AppColors.primary500 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  const _Grid({required this.query, required this.feed, required this.inLibrary});

  final DiscoverQuery query;
  final DiscoverFeedState feed;
  final Set<String> inLibrary;

  static const double _hPad = 16;
  static const double _colGap = 12;
  static const double _rowGap = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, box) {
        final cardWidth = (box.maxWidth - _hPad * 2 - _colGap * 2) / 3;
        final extent = DiscoverBookCard.coverHeightFor(cardWidth) +
            DiscoverBookCard.infoHeight;

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            // RN onEndReachedThreshold 0.5 = within half a viewport of the end.
            if (n.metrics.extentAfter < n.metrics.viewportDimension * 0.5) {
              ref.read(discoverFeedProvider(query).notifier).loadMore();
            }
            return false;
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_hPad, 0, _hPad, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: _colGap,
                    mainAxisSpacing: _rowGap,
                    mainAxisExtent: extent,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final b = feed.books[i];
                      return DiscoverBookCard(
                        book: b,
                        width: cardWidth,
                        isInLibrary: inLibrary.contains(b.id.toString()),
                        onTap: () =>
                            context.push(AppRoutes.bookDetailPath('${b.id}')),
                      );
                    },
                    childCount: feed.books.length,
                  ),
                ),
              ),
              if (feed.isFetchingNext)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary500,
                        ),
                      ),
                    ),
                  ),
                ),
              if (feed.nextError != null && !feed.isFetchingNext)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: GestureDetector(
                        onTap: () => ref
                            .read(discoverFeedProvider(query).notifier)
                            .loadMore(retry: true),
                        child: Text(
                          'Tap to retry',
                          style: AppTypography.label(
                            size: 13,
                            weight: FontWeight.w500,
                            color: AppColors.primary500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
