import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/bottom_sheet_scaffold.dart';
import '../../../widgets/pressable_opacity.dart';

/// Shows the note editor. Resolves to the trimmed note, or `null` if cancelled.
Future<String?> showNoteEditor(
  BuildContext context, {
  required String selectedText,
  String initialNote = '',
}) {
  return showAppBottomSheet<String>(
    context,
    builder: (_) => NoteEditorSheet(
      selectedText: selectedText,
      initialNote: initialNote,
    ),
  );
}

/// RN `NoteEditor` (UI_SPEC §4.12): "Add Note", quote box with 3 px bar,
/// multiline input 100–180 px (max 2000 chars) + counter, Cancel / Save Note.
/// Keyboard aware.
class NoteEditorSheet extends StatefulWidget {
  const NoteEditorSheet({
    super.key,
    required this.selectedText,
    this.initialNote = '',
  });

  final String selectedText;
  final String initialNote;

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialNote);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final quote = widget.selectedText.length > 150
        ? '${widget.selectedText.substring(0, 150)}...'
        : widget.selectedText;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + (keyboard > 0 ? 0 : safeBottom)),
        decoration: const BoxDecoration(
          color: AppColors.elevated,
          border: Border(top: BorderSide(color: AppColors.borderLight)),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 4 + 16),
              Text('Add Note', style: AppTypography.label(size: 17, weight: FontWeight.w600)),
              const SizedBox(height: 16),
              if (widget.selectedText.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 3,
                          decoration: BoxDecoration(
                            color: AppColors.primary500,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            quote,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label(
                              size: 13,
                              color: AppColors.textSecondary,
                              lineHeight: 19,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                constraints: const BoxConstraints(minHeight: 100, maxHeight: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  maxLength: 2000,
                  maxLines: null,
                  minLines: 4,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  cursorColor: AppColors.primary500,
                  style: AppTypography.body15,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Add your thoughts...',
                    hintStyle: AppTypography.label(size: 15, color: AppColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_ctrl.text.length} / 2000',
                  style: AppTypography.label(size: 12, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: PressableOpacity(
                      pressedOpacity: 0.8,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTypography.label(
                            size: 15,
                            weight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PressableOpacity(
                      pressedOpacity: 0.85,
                      onTap: () => Navigator.of(context).pop(_ctrl.text.trim()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary500,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Save Note',
                          style: AppTypography.label(
                            size: 15,
                            weight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
