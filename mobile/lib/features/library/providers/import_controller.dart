import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_import_service.dart';
import 'library_providers.dart';

class ImportBatchState {
  const ImportBatchState({
    this.busy = false,
    this.done = 0,
    this.total = 0,
    this.outcomes = const [],
  });

  final bool busy;
  final int done;
  final int total;
  final List<ImportOutcome> outcomes;

  double? get progress => total == 0 ? null : done / total;

  ImportBatchState copyWith({bool? busy, int? done, int? total, List<ImportOutcome>? outcomes}) =>
      ImportBatchState(
        busy: busy ?? this.busy,
        done: done ?? this.done,
        total: total ?? this.total,
        outcomes: outcomes ?? this.outcomes,
      );
}

/// Runs batches of imports (picker, folder scan, "Share → ReadIn") and keeps the
/// library fresh. Only one batch runs at a time.
class ImportController extends StateNotifier<ImportBatchState> {
  ImportController(this._ref) : super(const ImportBatchState());

  final Ref _ref;

  Future<List<ImportOutcome>> run(List<String> paths) async {
    if (state.busy || paths.isEmpty) return const [];
    state = ImportBatchState(busy: true, total: paths.length);

    final known = <String>{
      for (final b in _ref.read(libraryProvider).valueOrNull?.books ?? const [])
        if (b.fingerprint.isNotEmpty) b.fingerprint,
    };

    final out = await _ref.read(localImportServiceProvider).importMany(
      paths,
      knownFingerprints: known,
      onProgress: (done, total) {
        if (mounted) state = state.copyWith(done: done);
      },
    );

    if (out.any((o) => o.ok)) _ref.invalidate(libraryProvider);
    if (mounted) state = ImportBatchState(outcomes: out);
    return out;
  }

  /// Short human summary: "Imported 3 books · 1 already in your library · 1 failed".
  static String summarize(List<ImportOutcome> outcomes) {
    final ok = outcomes.where((o) => o.ok).length;
    final dup = outcomes.where((o) => o.status == ImportStatus.duplicate).length;
    final bad = outcomes
        .where((o) => o.status == ImportStatus.failed || o.status == ImportStatus.unsupported)
        .length;
    final limit = outcomes.any((o) => o.status == ImportStatus.limit);
    final parts = <String>[];
    if (ok > 0) parts.add('Imported $ok ${ok == 1 ? 'file' : 'files'}');
    if (dup > 0) parts.add('$dup already in your library');
    if (bad > 0) parts.add('$bad could not be imported');
    if (limit) parts.add('library limit reached');
    return parts.isEmpty ? 'Nothing was imported.' : parts.join(' · ');
  }
}

final importControllerProvider =
    StateNotifierProvider<ImportController, ImportBatchState>((ref) => ImportController(ref));
