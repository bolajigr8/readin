import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../core/formats.dart';
import '../../../core/services/native_bridge.dart';
import '../../../core/services/routes.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../library/data/local_import_service.dart';
import '../../library/providers/import_controller.dart';
import '../../library/utils/open_book.dart';
import '../widgets/dashed_border.dart';

/// UI_SPEC §4.11 — "Import" (local-first): pick files or a whole folder; the
/// files stay on the phone, only a small record goes to the server.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  bool _picking = false;

  Future<void> _pickFiles() async {
    if (_picking) return;
    setState(() => _picking = true);
    List<String> paths = const [];
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: false,
      );
      paths = res?.files.map((f) => f.path).whereType<String>().toList() ?? const [];
    } catch (_) {
      AppToast.error('Could not open the file picker.');
    }
    if (mounted) setState(() => _picking = false);
    await _import(paths);
  }

  Future<void> _pickFolder() async {
    if (_picking) return;
    setState(() => _picking = true);
    final paths = await NativeFiles.pickFolder();
    if (mounted) setState(() => _picking = false);
    if (paths.isEmpty) {
      if (mounted) AppToast.info('No supported files found in that folder.');
      return;
    }
    await _import(paths);
  }

  Future<void> _import(List<String> paths) async {
    if (paths.isEmpty || !mounted) return;
    final outcomes = await ref.read(importControllerProvider.notifier).run(paths);
    if (!mounted || outcomes.isEmpty) return;

    final router = GoRouter.of(context);
    final limit = outcomes.where((o) => o.status == ImportStatus.limit).toList();

    if (outcomes.length == 1 && outcomes.first.book != null) {
      // One file: just open it.
      AppToast.success(ImportController.summarize(outcomes));
      router.go(AppRoutes.libraryTab);
      openBookWith(router, outcomes.first.book!);
      return;
    }

    if (limit.isNotEmpty) {
      final upgrade = await showConfirmDialog(
        context,
        title: 'Library Limit Reached',
        message: limit.first.message ?? 'Free plan is limited to 10 books.',
        confirmLabel: 'Upgrade',
        cancelLabel: 'Not now',
      );
      if (upgrade && mounted) {
        router.go(AppRoutes.upgrade);
        return;
      }
    }

    if (!mounted) return;
    await _showSummary(outcomes);
    if (mounted) router.go(AppRoutes.libraryTab);
  }

  Future<void> _showSummary(List<ImportOutcome> outcomes) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        title: Text(ImportController.summarize(outcomes), style: AppTypography.section17),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final o in outcomes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          o.ok
                              ? Ionicons.checkmark_circle
                              : o.status == ImportStatus.duplicate
                                  ? Ionicons.copy_outline
                                  : Ionicons.alert_circle_outline,
                          size: 16,
                          color: o.ok
                              ? AppColors.success500
                              : o.status == ImportStatus.duplicate
                                  ? AppColors.textMuted
                                  : AppColors.error500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label(size: 13, weight: FontWeight.w500),
                              ),
                              if (o.message != null)
                                Text(
                                  o.message!,
                                  style: AppTypography.label(size: 11, color: AppColors.textMuted),
                                ),
                              if (o.status == ImportStatus.pending)
                                Text(
                                  'Saved on this phone · will sync when the server is reachable',
                                  style: AppTypography.label(size: 11, color: AppColors.textMuted),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Done',
              style: AppTypography.label(size: 14, weight: FontWeight.w600, color: AppColors.primary500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final batch = ref.watch(importControllerProvider);
    final busy = batch.busy || _picking;

    return PopScope(
      canPop: !batch.busy,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Import',
                            style: AppTypography.label(size: 26, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Books, documents, sheets, comics — right from your phone',
                            style: AppTypography.label(
                              size: 14,
                              color: AppColors.textSecondary,
                              lineHeight: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: PressableOpacity(
                        pressedOpacity: 0.75,
                        semanticLabel: 'Close',
                        onTap: batch.busy
                            ? null
                            : () => context.canPop()
                                ? context.pop()
                                : context.go(AppRoutes.libraryTab),
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.elevated,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Ionicons.close, size: 20, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  'WHAT YOU CAN OPEN',
                  style: AppTypography.label(
                    size: 11,
                    weight: FontWeight.w600,
                    letterSpacing: 1,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                const _FormatChips(),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.alpha(AppColors.amber400, 0x12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.alpha(AppColors.amber400, 0x35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Ionicons.flash_outline, size: 18, color: AppColors.amber400),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: AppTypography.label(
                              size: 13,
                              color: AppColors.textSecondary,
                              lineHeight: 20,
                            ),
                            children: [
                              TextSpan(
                                text: 'Instant and private.',
                                style: AppTypography.label(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  lineHeight: 20,
                                ),
                              ),
                              const TextSpan(
                                text:
                                    ' Files stay on your phone and open offline. Tip: in WhatsApp, Files or any app tap Share → ReadIn.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                PressableOpacity(
                  pressedOpacity: 0.8,
                  onTap: busy ? null : _pickFiles,
                  child: Opacity(
                    opacity: busy ? 0.6 : 1,
                    child: DashedRRectBorder(
                      color: AppColors.alpha(AppColors.primary500, 0x40),
                      fill: AppColors.surface,
                      radius: 16,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.alpha(AppColors.primary500, 0x15),
                              ),
                              child: const Icon(
                                Ionicons.cloud_upload_outline,
                                size: 40,
                                color: AppColors.primary500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              batch.busy
                                  ? 'Importing ${batch.done} of ${batch.total}...'
                                  : (_picking ? 'Opening picker...' : 'Choose files'),
                              style: AppTypography.section17,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              batch.busy
                                  ? 'Please keep the app open'
                                  : 'Select one or many — tap to browse',
                              style: AppTypography.label(size: 13, color: AppColors.textSecondary),
                            ),
                            if (batch.busy) ...[
                              const SizedBox(height: 14),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: batch.progress,
                                    minHeight: 4,
                                    backgroundColor: AppColors.borderLight,
                                    color: AppColors.primary500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Select Files',
                  size: AppButtonSize.lg,
                  expand: true,
                  loading: busy,
                  onPressed: _pickFiles,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Import a Folder',
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.lg,
                  expand: true,
                  leftIcon: const Icon(Ionicons.folder_open_outline, size: 20, color: AppColors.primary500),
                  onPressed: busy ? null : _pickFolder,
                ),
                const SizedBox(height: 24),
                Text(
                  'Folder import scans sub-folders (up to 200 files).',
                  textAlign: TextAlign.center,
                  style: AppTypography.label(size: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid of the formats ReadIn opens, coloured by how they are opened.
class _FormatChips extends StatelessWidget {
  const _FormatChips();

  static const _shown = [
    'pdf', 'epub', 'docx', 'xlsx', 'pptx', 'txt', 'md', 'csv', 'html', 'cbz', 'fb2', 'odt',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final ext in _shown)
          Builder(builder: (context) {
            final f = formatForExtension(ext)!;
            final color = switch (f.kind) {
              ViewerKind.pdf => AppColors.error400,
              ViewerKind.epub => AppColors.primary500,
              ViewerKind.comic => AppColors.purple500,
              _ => AppColors.blue500,
            };
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.alpha(color, 0x45)),
              ),
              child: Text(
                ext.toUpperCase(),
                style: AppTypography.label(size: 12, weight: FontWeight.w700, color: color),
              ),
            );
          }),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Text(
            '+ MOBI, DOC, RTF…  (open in another app)',
            style: AppTypography.label(size: 12, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}
