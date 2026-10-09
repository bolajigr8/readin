import '../../shelves/widgets/shelf_widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../core/services/routes.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_spinner.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/models/book.dart';
import '../providers/library_providers.dart';
import '../utils/library_logic.dart';
import '../widgets/book_grid.dart';
import 'home_screen.dart' show openBook;

/// UI_SPEC §4.8 — "My Library" tab.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late final TextEditingController _search;
  late final TapGestureRecognizer _upgradeTap;
  bool _showFreemiumBanner = true;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(librarySearchProvider));
    _upgradeTap = TapGestureRecognizer()
      ..onTap = () => context.go(AppRoutes.profile);
  }

  @override
  void dispose() {
    _search.dispose();
    _upgradeTap.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(Book book) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Book',
      message: 'Remove "${book.title}" from your library? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    final res = await ref.read(deleteBookProvider)(book);
    res.onFailure((e) => AppToast.error(e.message));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final lib = ref.watch(libraryProvider);
    final books = ref.watch(processedBooksProvider);
    final query = ref.watch(librarySearchProvider);
    final sort = ref.watch(librarySortProvider);
    final columns = ref.watch(libraryColumnsProvider);

    final isLoading = lib.isLoading && !lib.hasValue;
    final hasError = lib.hasError && !lib.hasValue;
    final limitReached = lib.valueOrNull?.meta.limitReached == true;
    final isFree = user?.plan == 'free';

    Widget content;
    if (isLoading) {
      content = const LoadingSpinner(fullScreen: true, label: 'Loading library...');
    } else if (hasError) {
      content = Center(
        child: EmptyState(
          icon: Ionicons.wifi_outline,
          title: 'Could not load library',
          description: 'Check your connection and pull down to retry.',
          actionLabel: 'Try Again',
          onAction: () => refreshLibrary(ref),
        ),
      );
    } else {
      final searching = query.isNotEmpty;
      content = BookGrid(
        books: books,
        columns: columns,
        onBookTap: (b) => openBook(context, b),
        onBookLongPress: (b) => showBookActions(context, book: b, onDelete: () => _confirmDelete(b)),
        onRefresh: () => refreshLibrary(ref),
        header: const SizedBox(height: 12),
        empty: EmptyState(
          icon: Ionicons.book_outline,
          title: searching ? 'No results for "$query"' : 'Your library is empty',
          description: searching
              ? 'Try a different title or author name.'
              : 'Import a PDF or EPUB, or discover a free classic to get started.',
          actionLabel: searching ? null : 'Import a Book',
          onAction:
              searching ? null : () => context.push(AppRoutes.importBook),
        ),
      );
    }

    return Column(
      children: [
        AppHeader(
          title: 'My Library',
          rightContent: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(AppRoutes.importBook),
            child: const Icon(
              Ionicons.add,
              size: 24,
              color: AppColors.primary500,
            ),
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
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Ionicons.search_outline,
                  size: 17,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (v) =>
                      ref.read(librarySearchProvider.notifier).state = v,
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
                    hintText: 'Search by title or author...',
                    hintStyle: AppTypography.label(
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              if (query.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _search.clear();
                    ref.read(librarySearchProvider.notifier).state = '';
                  },
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

        // Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SortDropdown(
                value: sort,
                onChanged: (k) =>
                    ref.read(librarySortProvider.notifier).state = k,
              ),
              Text(
                '${books.length} ${books.length == 1 ? 'book' : 'books'}',
                style: AppTypography.label(size: 13, color: AppColors.textMuted),
              ),
              _LayoutToggle(
                columns: columns,
                onChanged: (c) =>
                    ref.read(libraryColumnsProvider.notifier).state = c,
              ),
            ],
          ),
        ),

        // Freemium banner
        if (isFree && limitReached && _showFreemiumBanner)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.alpha(AppColors.amber400, 0x12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.alpha(AppColors.amber400, 0x35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Ionicons.lock_closed_outline,
                  size: 14,
                  color: AppColors.amber400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: '10-book limit reached. ',
                      style: AppTypography.label(
                        size: 13,
                        color: AppColors.textSecondary,
                        lineHeight: 18,
                      ),
                      children: [
                        TextSpan(
                          text: 'Upgrade to Premium',
                          recognizer: _upgradeTap,
                          style: AppTypography.label(
                            size: 13,
                            weight: FontWeight.w600,
                            color: AppColors.amber400,
                            lineHeight: 18,
                          ),
                        ),
                        const TextSpan(text: ' for unlimited books.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _showFreemiumBanner = false),
                  child: const Icon(
                    Ionicons.close,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

        const ShelfFilterBar(),
        Expanded(child: content),
      ],
    );
  }
}

/// Sort button + dropdown (absolute, `top: 38`, min-width 140).
class _SortDropdown extends StatefulWidget {
  const _SortDropdown({required this.value, required this.onChanged});

  final SortKey value;
  final ValueChanged<SortKey> onChanged;

  @override
  State<_SortDropdown> createState() => _SortDropdownState();
}

class _SortDropdownState extends State<_SortDropdown> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  bool _open = false;

  void _setOpen(bool v) {
    if (v) {
      _portal.show();
    } else {
      _portal.hide();
    }
    setState(() => _open = v);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _setOpen(false),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 38),
              child: Align(
                alignment: Alignment.topLeft,
                child: _Menu(
                  value: widget.value,
                  onSelect: (k) {
                    widget.onChanged(k);
                    _setOpen(false);
                  },
                ),
              ),
            ),
          ],
        ),
        child: PressableOpacity(
          pressedOpacity: 0.75,
          onTap: () => _setOpen(!_open),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Ionicons.funnel_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.value.label,
                  style: AppTypography.label(
                    size: 13,
                    weight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  _open ? Ionicons.chevron_up : Ionicons.chevron_down,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.value, required this.onSelect});

  final SortKey value;
  final ValueChanged<SortKey> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.elevated,
      elevation: 8,
      shadowColor: AppColors.black,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 140),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final k in SortKey.values)
                PressableOpacity(
                  pressedOpacity: 0.7,
                  onTap: () => onSelect(k),
                  child: Container(
                    color: k == value
                        ? AppColors.alpha(AppColors.primary500, 0x12)
                        : null,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          k.label,
                          style: AppTypography.label(
                            size: 14,
                            color: k == value
                                ? AppColors.primary500
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (k == value) ...[
                          const SizedBox(width: 12),
                          const Icon(
                            Ionicons.checkmark,
                            size: 14,
                            color: AppColors.primary500,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({required this.columns, required this.onChanged});

  final int columns;
  final ValueChanged<int> onChanged;

  Widget _btn(IconData icon, bool active, VoidCallback onTap) => PressableOpacity(
        pressedOpacity: 0.75,
        onTap: onTap,
        child: Container(
          width: 34,
          height: 32,
          alignment: Alignment.center,
          color: active ? AppColors.alpha(AppColors.primary500, 0x20) : null,
          child: Icon(
            icon,
            size: 16,
            color: active ? AppColors.primary500 : AppColors.textMuted,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Ionicons.grid_outline, columns == 2, () => onChanged(2)),
          _btn(Ionicons.list_outline, columns == 1, () => onChanged(1)),
        ],
      ),
    );
  }
}
