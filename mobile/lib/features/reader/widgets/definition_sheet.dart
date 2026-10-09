import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../core/api/api_result.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/bottom_sheet_scaffold.dart';
import '../data/dictionary_service.dart';

/// Bottom sheet with the dictionary entry of [word] (loads on open).
Future<void> showDefinitionSheet(
  BuildContext context, {
  required String word,
  required DictionaryService service,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => _DefinitionSheet(word: word, service: service),
  );
}

class _DefinitionSheet extends StatefulWidget {
  const _DefinitionSheet({required this.word, required this.service});

  final String word;
  final DictionaryService service;

  @override
  State<_DefinitionSheet> createState() => _DefinitionSheetState();
}

class _DefinitionSheetState extends State<_DefinitionSheet> {
  late Future<ApiResult<DictionaryEntry>> _future = widget.service.lookup(widget.word);

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.6;
    return BottomSheetScaffold(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH, minHeight: 120),
        child: FutureBuilder<ApiResult<DictionaryEntry>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary500),
                ),
              );
            }
            final res = snap.data;
            final entry = res?.dataOrNull;
            if (entry == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      res?.exceptionOrNull?.message ?? 'No definition found.',
                      textAlign: TextAlign.center,
                      style: AppTypography.label(size: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => setState(() => _future = widget.service.lookup(widget.word)),
                      child: Text(
                        'Try again',
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
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.word.isEmpty ? widget.word : entry.word,
                    style: AppTypography.label(size: 22, weight: FontWeight.w700),
                  ),
                  if (entry.phonetic != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.phonetic!,
                      style: AppTypography.label(size: 14, color: AppColors.textMuted),
                    ),
                  ],
                  for (final m in entry.meanings.take(4)) ...[
                    const SizedBox(height: 16),
                    Text(
                      m.partOfSpeech,
                      style: AppTypography.label(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.primary500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (var i = 0; i < m.definitions.take(3).length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}. ${m.definitions[i].text}',
                              style: AppTypography.label(size: 14, lineHeight: 21),
                            ),
                            if (m.definitions[i].example != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2, left: 16),
                                child: Text(
                                  '"${m.definitions[i].example}"',
                                  style: AppTypography.label(
                                    size: 13,
                                    color: AppColors.textMuted,
                                    lineHeight: 19,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (m.synonyms.isNotEmpty)
                      Text(
                        'Synonyms: ${m.synonyms.take(5).join(', ')}',
                        style: AppTypography.label(size: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
