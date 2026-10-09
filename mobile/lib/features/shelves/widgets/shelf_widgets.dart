import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../core/services/routes.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/bottom_sheet_scaffold.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../library/data/models/book.dart';
import '../shelf_models.dart';
import '../shelf_providers.dart';

Future<String?> _askName(BuildContext context, String title, {String initial = ''}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.elevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      title: Text(title, style: AppTypography.section17),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 30,
        textCapitalization: TextCapitalization.sentences,
        cursorColor: AppColors.primary500,
        style: AppTypography.body15,
        decoration: const InputDecoration(hintText: 'Shelf name'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancel', style: AppTypography.label(size: 14, color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
          child: Text(
            'Save',
            style: AppTypography.label(size: 14, weight: FontWeight.w600, color: AppColors.primary500),
          ),
        ),
      ],
    ),
  );
}

/// Filter chips under the library search: All · Reading · Want to read ·
/// Finished · your shelves · "+ Shelf".
class ShelfFilterBar extends ConsumerWidget {
  const ShelfFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(shelvesProvider);
    final filter = ref.watch(shelfFilterProvider);
    final ctl = ref.read(shelfFilterProvider.notifier);

    Widget chip(String label, bool active, VoidCallback onTap, {VoidCallback? onLong}) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: PressableOpacity(
          pressedOpacity: 0.75,
          semanticLabel: label,
          onTap: onTap,
          onLongPress: onLong,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: active ? AppColors.alpha(AppColors.primary500, 0x18) : AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: active ? AppColors.primary500 : AppColors.borderDefault),
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
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
        children: [
          chip('All', filter.isAll, () => ctl.state = const ShelfFilter.all()),
          chip('Reading', filter.status == ReadStatus.reading,
              () => ctl.state = const ShelfFilter.status(ReadStatus.reading)),
          chip('Want to read', filter.status == ReadStatus.want,
              () => ctl.state = const ShelfFilter.status(ReadStatus.want)),
          chip('Finished', filter.status == ReadStatus.finished,
              () => ctl.state = const ShelfFilter.status(ReadStatus.finished)),
          for (final s in data.shelves)
            chip(
              s.name,
              filter.shelfId == s.id,
              () => ctl.state = ShelfFilter.shelf(s.id),
              onLong: () async {
                final n = await _askName(context, 'Rename shelf', initial: s.name);
                if (n != null && n.isNotEmpty) ref.read(shelvesProvider.notifier).renameShelf(s.id, n);
              },
            ),
          chip('+ Shelf', false, () async {
            final n = await _askName(context, 'New shelf');
            if (n != null && n.isNotEmpty) {
              final shelf = ref.read(shelvesProvider.notifier).createShelf(n);
              ctl.state = ShelfFilter.shelf(shelf.id);
            }
          }),
        ],
      ),
    );
  }
}

/// Long-press menu of a library book: status, shelves, delete.
Future<void> showBookActions(
  BuildContext context, {
  required Book book,
  required VoidCallback onDelete,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final data = ref.watch(shelvesProvider);
        final ctl = ref.read(shelvesProvider.notifier);
        final current = effectiveStatus(book, data);

        Widget label(String t) => Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                t,
                style: AppTypography.label(
                  size: 11,
                  weight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
            );

        return BottomSheetScaffold(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.section17,
              ),
              label('STATUS'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in const [ReadStatus.want, ReadStatus.reading, ReadStatus.finished])
                    ChoiceChip(
                      label: Text(statusLabel(s)),
                      selected: current == s,
                      showCheckmark: false,
                      selectedColor: AppColors.alpha(AppColors.primary500, 0x25),
                      backgroundColor: AppColors.surface,
                      side: BorderSide(
                        color: current == s ? AppColors.primary500 : AppColors.borderDefault,
                      ),
                      labelStyle: AppTypography.label(
                        size: 13,
                        color: current == s ? AppColors.primary500 : AppColors.textSecondary,
                      ),
                      onSelected: (_) => ctl.setStatus(book, current == s ? ReadStatus.none : s),
                    ),
                ],
              ),
              label('SHELVES'),
              if (data.shelves.isEmpty)
                Text(
                  'No shelves yet — create one to group books (e.g. "Sci-fi", "Work").',
                  style: AppTypography.label(size: 13, color: AppColors.textMuted),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in data.shelves)
                    FilterChip(
                      label: Text(s.name),
                      selected: s.bookIds.contains(book.id),
                      showCheckmark: true,
                      checkmarkColor: AppColors.primary500,
                      selectedColor: AppColors.alpha(AppColors.primary500, 0x25),
                      backgroundColor: AppColors.surface,
                      side: BorderSide(
                        color: s.bookIds.contains(book.id)
                            ? AppColors.primary500
                            : AppColors.borderDefault,
                      ),
                      labelStyle: AppTypography.label(size: 13, color: AppColors.textSecondary),
                      onSelected: (_) => ctl.toggleOnShelf(s.id, book.id),
                    ),
                  ActionChip(
                    label: const Text('+ New shelf'),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.borderDefault),
                    labelStyle: AppTypography.label(size: 13, color: AppColors.primary500),
                    onPressed: () async {
                      final n = await _askName(ctx, 'New shelf');
                      if (n != null && n.isNotEmpty) {
                        final shelf = ctl.createShelf(n);
                        ctl.toggleOnShelf(shelf.id, book.id);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              PressableOpacity(
                pressedOpacity: 0.8,
                onTap: () {
                  Navigator.of(ctx).pop();
                  onDelete();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.alpha(AppColors.error500, 0x15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.alpha(AppColors.error500, 0x40)),
                  ),
                  child: Text(
                    'Delete from library',
                    style: AppTypography.label(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.error500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// "2026 Reading Challenge" card (Home + Profile). Tap to change the goal.
class ChallengeCard extends ConsumerWidget {
  const ChallengeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(challengeProvider);
    final pct = c.goal == 0 ? 0.0 : (c.finished / c.goal).clamp(0.0, 1.0).toDouble();

    return PressableOpacity(
      pressedOpacity: 0.85,
      onTap: () => _editGoal(context, ref, c.goal),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${c.year} Reading Challenge',
                    style: AppTypography.label(size: 15, weight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${c.finished} / ${c.goal}',
                  style: AppTypography.label(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppColors.primary500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppColors.borderDefault,
                color: pct >= 1 ? AppColors.success500 : AppColors.primary500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              challengePace(goal: c.goal, finished: c.finished, now: DateTime.now()),
              style: AppTypography.label(size: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  void _editGoal(BuildContext context, WidgetRef ref, int goal) {
    showAppBottomSheet<void>(
      context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final g = ref.watch(shelvesProvider).yearlyGoal;
          return BottomSheetScaffold(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Books I want to read this year', style: AppTypography.section17),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: g > 1
                          ? () => ref.read(shelvesProvider.notifier).setYearlyGoal(g - 1)
                          : null,
                      icon: const Icon(Ionicons.remove_circle_outline, color: AppColors.primary500),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        '$g',
                        textAlign: TextAlign.center,
                        style: AppTypography.label(size: 32, weight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => ref.read(shelvesProvider.notifier).setYearlyGoal(g + 1),
                      icon: const Icon(Ionicons.add_circle_outline, color: AppColors.primary500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push(AppRoutes.badges);
                  },
                  child: Text(
                    'See my badges',
                    style: AppTypography.label(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.primary500,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
