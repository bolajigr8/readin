import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../constants/app_colors.dart';
import '../../core/services/routes.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/bottom_sheet_scaffold.dart';
import '../../widgets/pressable_opacity.dart';
import '../annotations/providers/annotations_providers.dart';
import '../library/data/models/book.dart';
import '../library/providers/library_providers.dart';
import '../library/utils/open_book.dart';
import 'notes_export.dart';
import 'quote_card.dart';

/// Every highlight and note of every book (loaded per book, 4 at a time).
final allNotesProvider = FutureProvider.autoDispose<List<NoteGroup>>((ref) async {
  final link = ref.keepAlive();
  Future<void>.delayed(const Duration(minutes: 5), link.close);

  final books = (ref.watch(libraryProvider).valueOrNull?.books ?? const <Book>[])
      .where((b) => !b.id.startsWith('local_'))
      .toList();
  final repo = ref.read(annotationsRepositoryProvider);
  final out = <NoteGroup>[];
  for (var i = 0; i < books.length; i += 4) {
    final batch = books.skip(i).take(4).toList();
    final results = await Future.wait(batch.map((b) => repo.list(b.id)));
    for (var k = 0; k < batch.length; k++) {
      final items = results[k].dataOrNull ?? const [];
      if (items.isNotEmpty) {
        final sorted = [...items]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        out.add(NoteGroup(
          bookId: batch[k].id,
          title: batch[k].title,
          author: batch[k].author,
          items: sorted,
        ));
      }
    }
  }
  return out;
});

/// Export sheet: copy as Markdown / text, or save a `.md` file.
Future<void> showExportSheet(BuildContext context, List<NoteGroup> groups, {String fileName = 'readin-notes'}) {
  final md = exportMarkdown(groups);
  final txt = exportText(groups);
  return showAppBottomSheet<void>(
    context,
    builder: (ctx) {
      Widget option(IconData icon, String title, String sub, Future<void> Function() action) {
        return PressableOpacity(
          pressedOpacity: 0.75,
          onTap: () async {
            Navigator.of(ctx).pop();
            await action();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primary500),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.label(size: 15, weight: FontWeight.w500)),
                      Text(sub, style: AppTypography.label(size: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return BottomSheetScaffold(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Export notes & highlights', style: AppTypography.section17),
            const SizedBox(height: 6),
            option(Ionicons.copy_outline, 'Copy as Markdown', 'For Obsidian, Notion, Bear…', () async {
              await Clipboard.setData(ClipboardData(text: md));
              AppToast.success('Copied as Markdown');
            }),
            option(Ionicons.document_text_outline, 'Copy as plain text', 'For any app', () async {
              await Clipboard.setData(ClipboardData(text: txt));
              AppToast.success('Copied as text');
            }),
            option(Ionicons.download_outline, 'Save as .md file', 'Choose where to save it', () async {
              try {
                final saved = await FilePicker.platform.saveFile(
                  dialogTitle: 'Save notes',
                  fileName: '$fileName.md',
                  bytes: Uint8List.fromList(utf8.encode(md)),
                );
                if (saved != null) AppToast.success('Saved');
              } catch (_) {
                AppToast.error('Could not save the file.');
              }
            }),
          ],
        ),
      );
    },
  );
}

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go(AppRoutes.profile);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allNotesProvider);
    final all = async.valueOrNull ?? const <NoteGroup>[];
    final groups = searchNotes(all, _query);
    final total = groups.fold<int>(0, (n, g) => n + g.items.length);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  PressableOpacity(
                    pressedOpacity: 0.7,
                    semanticLabel: 'Back',
                    onTap: _back,
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Ionicons.arrow_back, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notes & Highlights',
                      style: AppTypography.label(size: 20, weight: FontWeight.w700),
                    ),
                  ),
                  PressableOpacity(
                    pressedOpacity: 0.7,
                    semanticLabel: 'Export',
                    onTap: groups.isEmpty ? null : () => showExportSheet(context, groups),
                    child: Opacity(
                      opacity: groups.isEmpty ? 0.35 : 1,
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Ionicons.share_outline, color: AppColors.primary500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Row(
                children: [
                  const Icon(Ionicons.search_outline, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      cursorColor: AppColors.primary500,
                      style: AppTypography.label(size: 15),
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'Search quotes, notes, books...',
                        hintStyle: AppTypography.label(size: 15, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!async.isLoading || all.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$total ${total == 1 ? 'item' : 'items'} in ${groups.length} ${groups.length == 1 ? 'book' : 'books'}',
                    style: AppTypography.label(size: 12, color: AppColors.textMuted),
                  ),
                ),
              ),
            Expanded(
              child: async.isLoading && all.isEmpty
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary500))
                  : groups.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              _query.isEmpty
                                  ? 'No highlights yet.\nSelect text while reading to highlight it or add a note.'
                                  : 'Nothing matches "$_query".',
                              textAlign: TextAlign.center,
                              style: AppTypography.label(size: 14, color: AppColors.textSecondary, lineHeight: 21),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                          children: [for (final g in groups) _GroupView(group: g)],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupView extends ConsumerWidget {
  const _GroupView({required this.group});

  final NoteGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(libraryProvider).valueOrNull?.books ?? const <Book>[];
    final book = books.where((b) => b.id == group.bookId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: PressableOpacity(
            pressedOpacity: 0.75,
            onTap: book == null ? null : () => openBookWith(GoRouter.of(context), book),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label(size: 15, weight: FontWeight.w600),
                      ),
                      if (group.author.isNotEmpty)
                        Text(group.author, style: AppTypography.label(size: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Text(
                  '${group.items.length}',
                  style: AppTypography.label(size: 13, weight: FontWeight.w600, color: AppColors.primary500),
                ),
              ],
            ),
          ),
        ),
        for (final a in group.items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
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
                    decoration: BoxDecoration(color: a.color.color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.selectedText,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label(size: 13, lineHeight: 19, fontStyle: FontStyle.italic),
                        ),
                        if (a.hasNote) ...[
                          const SizedBox(height: 6),
                          Text(
                            a.note,
                            style: AppTypography.label(size: 12, color: AppColors.textSecondary, lineHeight: 17),
                          ),
                        ],
                        if (a.chapterTitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            a.chapterTitle,
                            style: AppTypography.label(size: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      PressableOpacity(
                        pressedOpacity: 0.7,
                        semanticLabel: 'Copy quote',
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: a.selectedText));
                          AppToast.info('Copied');
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Ionicons.copy_outline, size: 16, color: AppColors.textMuted),
                        ),
                      ),
                      PressableOpacity(
                        pressedOpacity: 0.7,
                        semanticLabel: 'Share as image',
                        onTap: () => showQuoteCardSheet(
                          context,
                          quote: a.selectedText,
                          bookTitle: group.title,
                          author: group.author,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Ionicons.image_outline, size: 16, color: AppColors.primary500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
