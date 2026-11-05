import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../core/formats.dart';
import '../../../core/services/native_bridge.dart';
import '../../../core/services/routes.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../shelves/shelf_models.dart';
import '../../shelves/shelf_providers.dart';
import '../../shelves/widgets/shelf_widgets.dart';
import '../data/models/book.dart';
import '../providers/download_providers.dart';
import '../providers/library_providers.dart';
import '../utils/open_book.dart';
import '../widgets/book_cover.dart';

/// "About" page shown when you tap a book: cover, quick actions, author,
/// summary, language, progress — and the READ / listen buttons.
class BookAboutScreen extends ConsumerWidget {
  const BookAboutScreen({super.key, required this.bookId, this.book});

  final String bookId;
  final Book? book;

  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(AppRoutes.libraryTab);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefer the live library entry (fresh progress) over the passed object.
    final live = ref.watch(libraryProvider).valueOrNull?.books.where((b) => b.id == bookId).firstOrNull;
    final b = live ?? book;
    if (b == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: TextButton(
              onPressed: () => _back(context),
              child: const Text('Book not found — go back'),
            ),
          ),
        ),
      );
    }

    final meta = ref.watch(bookMetaProvider(b.id)).valueOrNull;
    final data = ref.watch(shelvesProvider);
    final ctl = ref.read(shelvesProvider.notifier);
    final status = effectiveStatus(b, data);
    final fav = data.favorites.contains(b.id);
    final router = GoRouter.of(context);
    final pct = b.progress?.percentage ?? 0;
    final last = b.progress?.lastReadAt;
    final canListen = b.kind == ViewerKind.epub;
    final isDoc = b.kind != ViewerKind.epub && b.kind != ViewerKind.pdf;
    final summary = (meta?.description ?? '').isNotEmpty ? meta!.description : b.description;
    final language = (meta?.language ?? '').isNotEmpty ? meta!.language : b.language;

    Widget info(String value, String label) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTypography.label(size: 15, lineHeight: 22)),
              const SizedBox(height: 2),
              Text(label, style: AppTypography.label(size: 12, color: AppColors.textMuted)),
            ],
          ),
        );

    Widget action(IconData icon, bool active, String label, VoidCallback t, {Color? color}) =>
        PressableOpacity(
          pressedOpacity: 0.7,
          semanticLabel: label,
          onTap: t,
          child: SizedBox(
            width: 48,
            height: 44,
            child: Icon(icon, size: 26, color: color ?? (active ? AppColors.primary500 : AppColors.textSecondary)),
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  PressableOpacity(
                    pressedOpacity: 0.7,
                    semanticLabel: 'Back',
                    onTap: () => _back(context),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Ionicons.arrow_back, color: AppColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    child: Text('About', style: AppTypography.label(size: 18, weight: FontWeight.w600)),
                  ),
                  PressableOpacity(
                    pressedOpacity: 0.8,
                    onTap: () => openBookWith(router, b),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.primary500,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'READ',
                        style: AppTypography.label(size: 14, weight: FontWeight.w700, color: AppColors.white),
                      ),
                    ),
                  ),
                  if (canListen) ...[
                    const SizedBox(width: 6),
                    PressableOpacity(
                      pressedOpacity: 0.7,
                      semanticLabel: 'Listen',
                      onTap: () => router.push('${AppRoutes.readerPath(b.id)}?listen=1', extra: b),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Ionicons.volume_medium_outline, size: 26, color: AppColors.primary500),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 230),
                        child: AspectRatio(
                          aspectRatio: 0.7,
                          child: LayoutBuilder(
                            builder: (context, box) => BookCover(
                              title: b.title,
                              coverUrl: b.coverUrl,
                              width: box.maxWidth,
                              height: box.maxHeight,
                              radius: 10,
                              initialsSize: 44,
                              bookId: b.id,
                              badge: isDoc ? labelOfFormat(b.format) : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(b.title, style: AppTypography.label(size: 24, lineHeight: 31)),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        action(fav ? Ionicons.star : Ionicons.star_outline, fav, 'Favourite',
                            () => ctl.toggleFavorite(b.id)),
                        action(Ionicons.time_outline, status == ReadStatus.want, 'Want to read',
                            () => ctl.setStatus(b, status == ReadStatus.want ? ReadStatus.none : ReadStatus.want)),
                        action(Ionicons.checkmark_done_outline, status == ReadStatus.finished, 'Finished',
                            () => ctl.setStatus(b, status == ReadStatus.finished ? ReadStatus.none : ReadStatus.finished)),
                        action(Ionicons.library_outline, false, 'Shelves',
                            () => showBookActions(context, book: b, onDelete: () => _delete(context, ref, b))),
                        action(Ionicons.share_social_outline, false, 'Share file', () => _share(context, ref, b)),
                        action(Ionicons.trash_outline, false, 'Delete', () => _delete(context, ref, b),
                            color: AppColors.error500),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (b.author.isNotEmpty) info(b.author, 'Author'),
                    if (summary.isNotEmpty) _Summary(text: summary),
                    info('${labelOfFormat(b.format)}${b.fileSize > 0 ? ' · ${formatFileSize(b.fileSize)}' : ''}', 'Format & size'),
                    if (language.isNotEmpty) info(language.toUpperCase(), 'Language'),
                    info(
                      pct > 0
                          ? '${pct.round()}%${last != null ? ', ${DateFormat.yMMMd().add_jm().format(last.toLocal())}' : ''}'
                          : 'Not started',
                      'Progress & last read',
                    ),
                    if (b.pendingSync)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Saved on this phone — will sync when the server is reachable.',
                          style: AppTypography.label(size: 12, color: AppColors.textMuted),
                        ),
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

  Future<void> _share(BuildContext context, WidgetRef ref, Book b) async {
    final f = await ref.read(downloadServiceProvider).findLocal(b.id);
    if (f == null) {
      AppToast.warning('The file is not on this phone.');
      return;
    }
    final ok = await NativeFiles.share(f.path, mimeOfFormat(b.format));
    if (!ok) AppToast.warning('Could not open the share sheet.');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Book b) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Book',
      message: 'Remove "${b.title}" from your library and this phone?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    final res = await ref.read(deleteBookProvider)(b);
    if (!context.mounted) return;
    res.when(
      success: (_) {
        AppToast.success('Book deleted.');
        _back(context);
      },
      failure: (e) => AppToast.error(e.message),
    );
  }
}

/// Summary with "more / less".
class _Summary extends StatefulWidget {
  const _Summary({required this.text});
  final String text;

  @override
  State<_Summary> createState() => _SummaryState();
}

class _SummaryState extends State<_Summary> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > 220;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            maxLines: _open || !long ? null : 4,
            overflow: _open || !long ? TextOverflow.visible : TextOverflow.ellipsis,
            style: AppTypography.label(size: 15, lineHeight: 22),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text('Summary', style: AppTypography.label(size: 12, color: AppColors.textMuted)),
              if (long) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() => _open = !_open),
                  child: Text(
                    _open ? 'Less' : 'More',
                    style: AppTypography.label(size: 12, weight: FontWeight.w600, color: AppColors.primary500),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
