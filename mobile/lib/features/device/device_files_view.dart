import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../constants/app_colors.dart';
import '../../core/formats.dart';
import '../../core/services/routes.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/pressable_opacity.dart';
import '../import/data/import_models.dart';
import '../library/data/local_import_service.dart';
import '../library/providers/import_controller.dart';
import 'device_files.dart';

/// "My Library | On this phone" switch under the library header.
class LibraryModeSwitch extends ConsumerWidget {
  const LibraryModeSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(libraryModeProvider);

    Widget pill(String label, IconData icon, int value) {
      final on = mode == value;
      return Expanded(
        child: PressableOpacity(
          pressedOpacity: 0.8,
          semanticLabel: label,
          onTap: () => ref.read(libraryModeProvider.notifier).state = value,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? AppColors.alpha(AppColors.primary500, 0x1A) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: on ? AppColors.primary500 : Colors.transparent),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: on ? AppColors.primary500 : AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.label(
                    size: 13,
                    weight: on ? FontWeight.w600 : FontWeight.w400,
                    color: on ? AppColors.primary500 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          pill('My Library', Ionicons.library_outline, 0),
          pill('On this phone', Ionicons.phone_portrait_outline, 1),
        ],
      ),
    );
  }
}

/// Every document found on the phone. Tap = read it right where it is (no copy,
/// no server, instant). Select several → "Add to library" to sync them.
class DeviceFilesView extends ConsumerStatefulWidget {
  const DeviceFilesView({super.key});

  @override
  ConsumerState<DeviceFilesView> createState() => _DeviceFilesViewState();
}

class _DeviceFilesViewState extends ConsumerState<DeviceFilesView> with WidgetsBindingObserver {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _filter = 'all'; // all | pdf | epub | office | text | other
  int _sort = 0; // 0 newest · 1 name · 2 size
  final Set<String> _selected = {};
  bool _waitingForPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed || !_waitingForPermission) return;
    final n = ref.read(deviceFilesProvider.notifier);
    await n.refreshAccess();
    if (!mounted) return;
    if (ref.read(deviceFilesProvider).hasAccess) {
      _waitingForPermission = false;
      n.scan();
    }
  }

  static bool _matches(DeviceFile f, String filter) {
    switch (filter) {
      case 'pdf':
        return f.ext == 'pdf';
      case 'epub':
        return f.ext == 'epub';
      case 'office':
        return const {'docx', 'doc', 'xlsx', 'xls', 'pptx', 'ppt', 'odt', 'rtf', 'csv'}.contains(f.ext);
      case 'text':
        return const {'txt', 'md', 'html', 'htm'}.contains(f.ext);
      case 'other':
        return const {'mobi', 'azw3', 'fb2', 'cbz', 'cbr'}.contains(f.ext);
      default:
        return true;
    }
  }

  List<DeviceFile> _visible(List<DeviceFile> all) {
    final q = _query.trim().toLowerCase();
    final out = all
        .where((f) => _matches(f, _filter))
        .where((f) => q.isEmpty || f.name.toLowerCase().contains(q) || f.folder.toLowerCase().contains(q))
        .toList();
    switch (_sort) {
      case 1:
        out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case 2:
        out.sort((a, b) => b.size.compareTo(a.size));
      default:
        out.sort((a, b) => b.modified.compareTo(a.modified));
    }
    return out;
  }

  void _open(DeviceFile f) {
    final req = LocalReadRequest(path: f.path, title: f.title, format: f.ext);
    final kind = kindOfFormat(f.ext);
    if (kind == ViewerKind.epub || kind == ViewerKind.pdf) {
      context.push(AppRoutes.readerPath('local'), extra: req);
    } else {
      context.push(AppRoutes.documentPath('local'), extra: req);
    }
  }

  Future<void> _addSelected() async {
    final paths = _selected.toList();
    setState(() => _selected.clear());
    final out = await ref.read(importControllerProvider.notifier).run(paths);
    if (!mounted || out.isEmpty) return;
    AppToast.success(ImportController.summarize(out));
    if (out.any((o) => o.status == ImportStatus.limit)) {
      AppToast.warning(out.firstWhere((o) => o.status == ImportStatus.limit).message ?? 'Library limit reached.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(deviceFilesProvider);
    final n = ref.read(deviceFilesProvider.notifier);
    final batch = ref.watch(importControllerProvider);

    if (!st.hasAccess && st.files.isEmpty) {
      return _Permission(
        error: st.error,
        onAllow: () async {
          _waitingForPermission = true;
          await n.requestAccess();
        },
        onFolder: () => context.push(AppRoutes.importBook),
      );
    }

    final files = _visible(st.files);
    final df = DateFormat.yMMMd();

    Widget chip(String label, String value) {
      final on = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: PressableOpacity(
          pressedOpacity: 0.75,
          onTap: () => setState(() => _filter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: on ? AppColors.alpha(AppColors.primary500, 0x18) : AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: on ? AppColors.primary500 : AppColors.borderDefault),
            ),
            child: Text(
              label,
              style: AppTypography.label(
                size: 13,
                weight: on ? FontWeight.w600 : FontWeight.w400,
                color: on ? AppColors.primary500 : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                              style: AppTypography.label(size: 14),
                              onChanged: (v) => setState(() => _query = v),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: 'Search files and folders...',
                                hintStyle: AppTypography.label(size: 14, color: AppColors.textMuted),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<int>(
                    tooltip: 'Sort',
                    color: AppColors.elevated,
                    icon: const Icon(Ionicons.funnel_outline, size: 20, color: AppColors.textSecondary),
                    onSelected: (v) => setState(() => _sort = v),
                    itemBuilder: (_) => [
                      for (final e in const [(0, 'Newest first'), (1, 'Name (A–Z)'), (2, 'Largest first')])
                        PopupMenuItem(
                          value: e.$1,
                          child: Text(
                            e.$2,
                            style: AppTypography.label(
                              size: 14,
                              color: _sort == e.$1 ? AppColors.primary500 : AppColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                children: [
                  chip('All', 'all'),
                  chip('PDF', 'pdf'),
                  chip('EPUB', 'epub'),
                  chip('Word / Excel / Slides', 'office'),
                  chip('Text', 'text'),
                  chip('Other', 'other'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      st.scanning
                          ? 'Scanning your phone...'
                          : '${files.length} files${st.lastScan != null ? ' · scanned ${DateFormat.MMMd().add_jm().format(st.lastScan!)}' : ''}',
                      style: AppTypography.label(size: 12, color: AppColors.textMuted),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: st.scanning ? null : n.scan,
                    icon: st.scanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary500),
                          )
                        : const Icon(Ionicons.refresh_outline, size: 16, color: AppColors.primary500),
                    label: Text(
                      st.lastScan == null ? 'Scan now' : 'Rescan',
                      style: AppTypography.label(size: 13, weight: FontWeight.w600, color: AppColors.primary500),
                    ),
                  ),
                ],
              ),
            ),
            if (st.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Text(st.error!, style: AppTypography.label(size: 12, color: AppColors.error500)),
              ),
            Expanded(
              child: files.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          st.lastScan == null
                              ? 'Tap "Scan now" to find every book and document on your phone.'
                              : 'Nothing matches.',
                          textAlign: TextAlign.center,
                          style: AppTypography.label(size: 14, color: AppColors.textSecondary, lineHeight: 21),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, _selected.isEmpty ? 24 : 90),
                      itemCount: files.length,
                      itemBuilder: (context, i) {
                        final f = files[i];
                        final sel = _selected.contains(f.path);
                        final kind = kindOfFormat(f.ext);
                        final color = switch (kind) {
                          ViewerKind.pdf => AppColors.error400,
                          ViewerKind.epub => AppColors.primary500,
                          ViewerKind.comic => AppColors.purple500,
                          _ => AppColors.blue500,
                        };
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: PressableOpacity(
                            pressedOpacity: 0.85,
                            onTap: () {
                              if (_selected.isNotEmpty) {
                                setState(() => sel ? _selected.remove(f.path) : _selected.add(f.path));
                              } else {
                                _open(f);
                              }
                            },
                            onLongPress: () => setState(() => sel ? _selected.remove(f.path) : _selected.add(f.path)),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.alpha(AppColors.primary500, 0x12) : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: sel ? AppColors.primary500 : AppColors.borderDefault),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 56,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.alpha(color, 0x18),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.alpha(color, 0x50)),
                                    ),
                                    child: sel
                                        ? const Icon(Ionicons.checkmark_circle, color: AppColors.primary500)
                                        : Text(
                                            f.ext.toUpperCase(),
                                            style: AppTypography.label(size: 11, weight: FontWeight.w700, color: color),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          f.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.label(size: 14, weight: FontWeight.w600, lineHeight: 19),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${f.folder.isEmpty ? 'Phone' : f.folder}  ·  ${formatFileSize(f.size)}  ·  ${df.format(f.modified)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.label(size: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        if (_selected.isNotEmpty || batch.busy)
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Material(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(14),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        batch.busy ? 'Adding ${batch.done} of ${batch.total}...' : '${_selected.length} selected',
                        style: AppTypography.label(size: 14, weight: FontWeight.w600),
                      ),
                    ),
                    if (!batch.busy) ...[
                      TextButton(
                        onPressed: () => setState(_selected.clear),
                        child: Text('Clear', style: AppTypography.label(size: 13, color: AppColors.textSecondary)),
                      ),
                      PressableOpacity(
                        pressedOpacity: 0.85,
                        onTap: _addSelected,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.primary500,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Add to library',
                            style: AppTypography.label(size: 13, weight: FontWeight.w600, color: AppColors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Permission extends StatelessWidget {
  const _Permission({required this.onAllow, required this.onFolder, this.error});

  final VoidCallback onAllow;
  final VoidCallback onFolder;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Ionicons.phone_portrait_outline, size: 46, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text('Find every book on your phone', style: AppTypography.title20, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'ReadIn can scan your phone for PDFs, EPUBs, Word, Excel and other documents and list them here. They stay where they are — nothing is copied or uploaded. Android asks you to allow "All files access" for this.',
              textAlign: TextAlign.center,
              style: AppTypography.label(size: 14, color: AppColors.textSecondary, lineHeight: 21),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: AppTypography.label(size: 12, color: AppColors.error500)),
            ],
            const SizedBox(height: 22),
            PressableOpacity(
              pressedOpacity: 0.85,
              onTap: onAllow,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary500,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Allow and scan',
                  style: AppTypography.label(size: 15, weight: FontWeight.w600, color: AppColors.white),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onFolder,
              child: Text(
                'Prefer not to? Pick files or a folder instead',
                style: AppTypography.label(size: 13, color: AppColors.primary500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
