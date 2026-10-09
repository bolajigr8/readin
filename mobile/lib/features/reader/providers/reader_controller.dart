import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/providers/auth_providers.dart';
import '../../import/data/import_models.dart';
import '../../library/data/models/book.dart';
import '../../library/data/repositories/library_repository.dart';
import '../../library/data/services/download_service.dart';
import '../../library/providers/download_providers.dart';
import '../../goals/reading_goal.dart';
import '../../library/providers/library_providers.dart';
import '../data/dictionary_service.dart';
import '../data/progress_repository.dart';
import '../data/progress_sync.dart';
import '../data/reader_models.dart';
import '../../../core/services/storage_service.dart';

/// What the reader route was opened with. Equality is by [bookId] (+ local file
/// path), so the controller (family) is created once per book even if the
/// `extra` instances differ.
class ReaderArgs {
  const ReaderArgs({required this.bookId, this.book, this.local});

  final String bookId;
  final Book? book;
  final LocalReadRequest? local;

  @override
  bool operator ==(Object other) =>
      other is ReaderArgs && other.bookId == bookId && other.local?.path == local?.path;

  @override
  int get hashCode => Object.hash(bookId, local?.path);
}

enum ReaderPhase { loading, ready, error }

class ReaderState {
  const ReaderState({
    required this.prefs,
    this.phase = ReaderPhase.loading,
    this.isDownloading = false,
    this.downloadProgress,
    this.error,
    this.errorDetail,
    this.canRedownload = false,
    this.canRelink = false,
    this.title = '',
    this.format = 'epub',
    this.filePath,
    this.isLocal = false,
    this.initialCfi,
    this.initialPage,
    this.engineReady = false,
    this.toolbarVisible = true,
    this.percentage = 0,
    this.chapterIndex = 0,
    this.chapterTitle = '',
    this.toc = const [],
    this.currentCfi,
    this.pdfPage = 1,
    this.pdfPages = 0,
    this.locationsReady = false,
    this.minutesLeft,
    this.searchQuery = '',
    this.searchResults = const [],
    this.isSearching = false,
  });

  final ReaderPrefs prefs;
  final ReaderPhase phase;

  /// File is being downloaded; [downloadProgress] 0–1 (null = unknown size).
  final bool isDownloading;
  final double? downloadProgress;

  final String? error;

  /// Technical detail shown (small) on the error screen — makes bug reports easy.
  final String? errorDetail;
  final bool canRedownload;

  /// The book's file is not on this phone → offer "Choose the file".
  final bool canRelink;

  final String title;

  /// `'epub'` | `'pdf'`.
  final String format;
  final String? filePath;
  final bool isLocal;
  final String? initialCfi;
  final int? initialPage;

  /// epub.js rendered the first page / pdf document is loaded.
  final bool engineReady;
  final bool toolbarVisible;
  final int percentage;
  final int chapterIndex;
  final String chapterTitle;
  final List<TocItem> toc;
  final String? currentCfi;
  final int pdfPage;
  final int pdfPages;

  /// epub.js finished generating locations (enables the scrubber).
  final bool locationsReady;

  /// Estimated minutes left in the book from this session's pace (null = unknown).
  final int? minutesLeft;
  final String searchQuery;
  final List<SearchHit> searchResults;
  final bool isSearching;

  bool get isPdf => format == 'pdf';

  ReaderState copyWith({
    ReaderPrefs? prefs,
    ReaderPhase? phase,
    bool? isDownloading,
    double? downloadProgress,
    bool clearDownloadProgress = false,
    String? error,
    String? errorDetail,
    bool clearError = false,
    bool? canRedownload,
    bool? canRelink,
    String? title,
    String? format,
    String? filePath,
    bool? isLocal,
    String? initialCfi,
    int? initialPage,
    bool? engineReady,
    bool? toolbarVisible,
    int? percentage,
    int? chapterIndex,
    String? chapterTitle,
    List<TocItem>? toc,
    String? currentCfi,
    int? pdfPage,
    int? pdfPages,
    bool? locationsReady,
    int? minutesLeft,
    bool clearMinutesLeft = false,
    String? searchQuery,
    List<SearchHit>? searchResults,
    bool? isSearching,
  }) {
    return ReaderState(
      prefs: prefs ?? this.prefs,
      phase: phase ?? this.phase,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress:
          clearDownloadProgress ? null : (downloadProgress ?? this.downloadProgress),
      error: clearError ? null : (error ?? this.error),
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      canRedownload: canRedownload ?? this.canRedownload,
      canRelink: canRelink ?? this.canRelink,
      title: title ?? this.title,
      format: format ?? this.format,
      filePath: filePath ?? this.filePath,
      isLocal: isLocal ?? this.isLocal,
      initialCfi: initialCfi ?? this.initialCfi,
      initialPage: initialPage ?? this.initialPage,
      engineReady: engineReady ?? this.engineReady,
      toolbarVisible: toolbarVisible ?? this.toolbarVisible,
      percentage: percentage ?? this.percentage,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      toc: toc ?? this.toc,
      currentCfi: currentCfi ?? this.currentCfi,
      pdfPage: pdfPage ?? this.pdfPage,
      pdfPages: pdfPages ?? this.pdfPages,
      locationsReady: locationsReady ?? this.locationsReady,
      minutesLeft: clearMinutesLeft ? null : (minutesLeft ?? this.minutesLeft),
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

class ReaderController extends StateNotifier<ReaderState> {
  ReaderController({
    required this.args,
    required DownloadService downloads,
    required ProgressRepository progress,
    required LibraryRepository library,
    required StorageService storage,
    required void Function() onClosed,
    void Function(int seconds)? onTimeCounted,
  })  : _downloads = downloads,
        _progress = progress,
        _library = library,
        _storage = storage,
        _onClosed = onClosed,
        _onTimeCounted = onTimeCounted,
        super(
          ReaderState(
            prefs: ReaderPrefs(
              fontSize: storage.readerFontSize,
              fontFamily: storage.readerFontFamily,
              theme: storage.readerTheme,
              lineHeight: storage.readerLineHeight,
              margin: storage.readerMargin,
              align: storage.readerAlign,
              flow: storage.readerFlow,
              brightness: storage.readerBrightness,
              volumeKeys: storage.volumeKeysNav,
              warmth: storage.readerWarmth,
              autoNight: storage.readerAutoNight,
            ),
            isLocal: args.local != null,
          ),
        ) {
    _sync = ProgressSync(
      send: (payload, delta) => _progress.save(args.bookId, payload, delta),
    );
    if (args.bookId.isNotEmpty && args.local == null) _sync.start();
    _open();
  }

  final ReaderArgs args;
  final DownloadService _downloads;
  final ProgressRepository _progress;
  final LibraryRepository _library;
  final StorageService _storage;
  final void Function() _onClosed;
  final void Function(int seconds)? _onTimeCounted;
  late final ProgressSync _sync;

  /// Active reading time of this session (paused while in the background).
  final Stopwatch _reading = Stopwatch();
  int _startPercentage = -1;

  bool get _syncs => args.local == null && args.bookId.isNotEmpty;

  // ── opening ─────────────────────────────────────────────────────────────────

  Future<void> _open({bool allowRepair = true}) async {
    state = state.copyWith(
      phase: ReaderPhase.loading,
      clearError: true,
      engineReady: false,
      isDownloading: false,
      clearDownloadProgress: true,
    );

    // Local file (opened from the import screen) — no API at all.
    final local = args.local;
    if (local != null) {
      final ok = await DownloadService.hasValidMagicBytes(
        _file(local.path),
        local.format,
      );
      if (!mounted) return;
      if (!ok) {
        _fail('This file could not be opened. It may be corrupted.');
        return;
      }
      state = state.copyWith(
        phase: ReaderPhase.ready,
        title: local.title,
        format: local.format == 'pdf' ? 'pdf' : 'epub',
        filePath: local.path,
        isLocal: true,
      );
      return;
    }

    // Book: from `extra`, else GET /library/:id
    var book = args.book;
    if (book == null) {
      final res = await _library.getBook(args.bookId);
      if (!mounted) return;
      final detail = res.dataOrNull;
      if (detail == null) {
        _fail(res.exceptionOrNull?.message ?? 'Could not load this book.');
        return;
      }
      book = detail.book;
    }

    final format = book.format == 'pdf' ? 'pdf' : 'epub';
    state = state.copyWith(title: book.title, format: format);

    final progressFuture = _progress.get(book.id);

    File? file;
    try {
      file = await _downloads.ensureLocal(
        book,
        onProgress: (p) {
          if (!mounted) return;
          state = state.copyWith(
            isDownloading: true,
            downloadProgress: p,
            clearDownloadProgress: p == null,
          );
        },
      );
    } on AppException catch (e) {
      if (!mounted) return;
      _fail(
        e.message,
        canRedownload: e is InvalidFileException || e is DownloadException,
        canRelink: e is MissingLocalFileException,
        detail: '${e.runtimeType}${e.statusCode != null ? ' · HTTP ${e.statusCode}' : ''}',
      );
      return;
    } catch (_) {
      if (!mounted) return;
      _fail('Could not open this book.');
      return;
    }
    if (!mounted) return;

    // A truncated / corrupt copy on disk: delete and fetch again (once).
    if (!await DownloadService.hasValidMagicBytes(file, format)) {
      if (allowRepair) {
        await _downloads.delete(book.id);
        if (!mounted) return;
        await _open(allowRepair: false);
        return;
      }
      _fail('The book file is damaged.', canRedownload: true);
      return;
    }

    SavedProgress? saved;
    try {
      saved = (await progressFuture).dataOrNull;
    } catch (_) {
      saved = null; // no progress yet / offline — start at the beginning
    }
    if (!mounted) return;

    final cfi = saved?.currentCfi ?? '';
    state = state.copyWith(
      phase: ReaderPhase.ready,
      filePath: file.path,
      isDownloading: false,
      clearDownloadProgress: true,
      initialCfi: (format != 'pdf' && cfi.isNotEmpty && !cfi.startsWith('page:'))
          ? cfi
          : null,
      initialPage: saved?.pdfPage,
      percentage: saved == null ? 0 : saved.percentage.round().clamp(0, 100),
      currentCfi: cfi.isEmpty ? null : cfi,
    );
  }

  File _file(String path) => File(path);

  void _fail(String message, {bool canRedownload = false, bool canRelink = false, String? detail}) {
    state = state.copyWith(
      phase: ReaderPhase.error,
      error: message,
      errorDetail: detail,
      canRedownload: canRedownload && args.local == null,
      canRelink: canRelink,
      isDownloading: false,
      clearDownloadProgress: true,
    );
  }

  /// Error screen → "Re-download": drops the local copy and opens again.
  /// After the user picked the missing file again.
  Future<void> reopen() async {
    if (!mounted) return;
    await _open(allowRepair: false);
  }

  Future<void> redownload() async {
    if (args.local != null) return;
    await _downloads.delete(args.bookId);
    if (!mounted) return;
    await _open(allowRepair: false);
  }

  // ── reading clock (daily goal + time-left estimate) ─────────────────────────

  Timer? _goalTimer;
  int _countedSeconds = 0;

  void _startReadingClock() {
    if (_reading.isRunning) return;
    _reading.start();
    _goalTimer ??= Timer.periodic(const Duration(seconds: 30), (_) => _flushGoalTime());
  }

  void _stopReadingClock() {
    _flushGoalTime();
    _reading.stop();
  }

  void _flushGoalTime() {
    final total = _reading.elapsed.inSeconds;
    final delta = total - _countedSeconds;
    if (delta > 0) {
      _countedSeconds = total;
      _onTimeCounted?.call(delta);
    }
  }

  /// Minutes left from THIS session's pace; needs ≥ 90 s of reading and ≥ 1 %
  /// progress, otherwise unknown (null) so we never show a silly number.
  int? _estimateMinutesLeft(int pct) {
    if (_startPercentage < 0) {
      _startPercentage = pct;
      return null;
    }
    final seconds = _reading.elapsed.inSeconds;
    final gained = pct - _startPercentage;
    if (seconds < 90 || gained < 1) return state.minutesLeft;
    final perMinute = gained / (seconds / 60.0);
    if (perMinute <= 0) return null;
    return ((100 - pct) / perMinute).round().clamp(0, 60 * 999).toInt();
  }

  // ── engine events ───────────────────────────────────────────────────────────

  void onEpubReady() {
    if (!mounted) return;
    state = state.copyWith(engineReady: true);
    _startReadingClock();
  }

  void onLocationsReady() {
    if (!mounted) return;
    state = state.copyWith(locationsReady: true);
  }

  // ── in-book search ──────────────────────────────────────────────────────────

  void beginSearch(String query) {
    final q = query.trim();
    if (q.length < 2) {
      clearSearch();
      return;
    }
    state = state.copyWith(searchQuery: q, searchResults: const [], isSearching: true);
  }

  void onSearchResults(String query, List<SearchHit> hits) {
    if (!mounted || query != state.searchQuery) return;
    state = state.copyWith(searchResults: hits, isSearching: false);
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '', searchResults: const [], isSearching: false);
  }

  void onToc(List<TocItem> toc) {
    if (!mounted) return;
    state = state.copyWith(toc: toc);
  }

  /// epub.js `relocated`. [percentage] is 0 until locations are generated, in
  /// which case the last known value is kept (never overwrite saved progress
  /// with 0).
  void onEpubLocation({
    required String cfi,
    required int percentage,
    required int spineIndex,
    required String chapterTitle,
    required String href,
  }) {
    if (!mounted || cfi.isEmpty) return;
    final toc = state.toc;
    var chapter = tocIndexFor(toc, href);
    if (chapter < 0) {
      chapter = toc.isEmpty ? spineIndex : spineIndex.clamp(0, toc.length - 1);
    }
    final pct = percentage > 0 ? percentage.clamp(0, 100) : state.percentage;

    state = state.copyWith(
      currentCfi: cfi,
      percentage: pct,
      chapterIndex: chapter,
      chapterTitle: chapterTitle,
      minutesLeft: _estimateMinutesLeft(pct),
    );

    if (_syncs) {
      _sync.update(
        ProgressPayload(
          currentCfi: cfi,
          percentage: pct.toDouble(),
          currentChapter: chapter,
          currentChapterTitle: chapterTitle,
          totalChapters: toc.length,
        ),
      );
    }
  }

  void onPdfReady(int pages) {
    if (!mounted) return;
    state = state.copyWith(engineReady: true, pdfPages: pages);
    _startReadingClock();
  }

  void onPdfPage(int page, int pages) {
    if (!mounted || page < 1) return;
    final pct = pages > 0 ? ((page / pages) * 100).round().clamp(0, 100) : 0;
    state = state.copyWith(
      pdfPage: page,
      pdfPages: pages,
      percentage: pct,
      currentCfi: 'page:$page',
      minutesLeft: _estimateMinutesLeft(pct),
    );
    if (_syncs) {
      _sync.update(
        ProgressPayload(
          currentCfi: 'page:$page',
          percentage: pct.toDouble(),
          currentChapter: page - 1,
          currentChapterTitle: '',
          totalChapters: pages,
        ),
      );
    }
  }

  /// Returns true when the error is fatal (nothing is displayed yet).
  bool onEngineError(String message) {
    if (!mounted) return true;
    if (state.engineReady) return false; // a hiccup while reading: toast only
    final lower = message.toLowerCase();
    final friendly = lower.contains('epub') || lower.contains('defined')
        ? 'Could not open this EPUB. The file may be corrupted.'
        : 'Reader error: $message';
    _fail(friendly, canRedownload: true, detail: message);
    return true;
  }

  // ── toolbar ─────────────────────────────────────────────────────────────────

  void toggleToolbar() => state = state.copyWith(toolbarVisible: !state.toolbarVisible);

  void setToolbar(bool visible) {
    if (state.toolbarVisible != visible) {
      state = state.copyWith(toolbarVisible: visible);
    }
  }

  // ── preferences (persisted; the viewer is told, never rebuilt) ─────────────

  void setFontSize(double size) {
    final v = size.clamp(12.0, 28.0).toDouble();
    state = state.copyWith(prefs: state.prefs.copyWith(fontSize: v));
    unawaited(_storage.setReaderFontSize(v));
  }

  void setFontFamily(String family) {
    final f = family == 'serif' ? 'serif' : 'sans-serif';
    state = state.copyWith(prefs: state.prefs.copyWith(fontFamily: f));
    unawaited(_storage.setReaderFontFamily(f));
  }

  void setTheme(String theme) {
    final t = (theme == 'light' || theme == 'sepia' || theme == 'night') ? theme : 'dark';
    state = state.copyWith(prefs: state.prefs.copyWith(theme: t));
    unawaited(_storage.setReaderTheme(t));
  }

  void setLineHeight(double v) {
    final x = v.clamp(1.2, 2.2).toDouble();
    state = state.copyWith(prefs: state.prefs.copyWith(lineHeight: x));
    unawaited(_storage.setReaderLineHeight(x));
  }

  void setMargin(double v) {
    final x = v.clamp(0.0, 48.0).toDouble();
    state = state.copyWith(prefs: state.prefs.copyWith(margin: x));
    unawaited(_storage.setReaderMargin(x));
  }

  void setAlign(String v) {
    final a = v == 'justify' ? 'justify' : 'left';
    state = state.copyWith(prefs: state.prefs.copyWith(align: a));
    unawaited(_storage.setReaderAlign(a));
  }

  void setFlow(String v) {
    final f = v == 'scroll' ? 'scroll' : 'paged';
    state = state.copyWith(prefs: state.prefs.copyWith(flow: f));
    unawaited(_storage.setReaderFlow(f));
  }

  void setBrightness(double v) {
    final x = v.clamp(0.3, 1.0).toDouble();
    state = state.copyWith(prefs: state.prefs.copyWith(brightness: x));
    unawaited(_storage.setReaderBrightness(x));
  }

  void setWarmth(double v) {
    final x = v.clamp(0.0, 0.5).toDouble();
    state = state.copyWith(prefs: state.prefs.copyWith(warmth: x));
    unawaited(_storage.setReaderWarmth(x));
  }

  void setAutoNight(bool v) {
    state = state.copyWith(prefs: state.prefs.copyWith(autoNight: v));
    unawaited(_storage.setReaderAutoNight(v));
  }

  void setVolumeKeys(bool v) {
    state = state.copyWith(prefs: state.prefs.copyWith(volumeKeys: v));
    unawaited(_storage.setVolumeKeysNav(v));
  }

  // ── lifecycle ───────────────────────────────────────────────────────────────

  Future<void> onPause() {
    _stopReadingClock();
    return _syncs ? _sync.pause() : Future<void>.value();
  }

  void onResume() {
    if (state.engineReady) _startReadingClock();
    if (_syncs) _sync.resume();
  }

  Future<void> flush() => _syncs ? _sync.flush() : Future<void>.value();

  @override
  void dispose() {
    _flushGoalTime();
    _reading.stop();
    _goalTimer?.cancel();
    // Final progress flush, then refresh the library bars.
    if (_syncs) {
      _sync.dispose().whenComplete(_onClosed);
    }
    super.dispose();
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(apiClientProvider)),
);

final readerControllerProvider = StateNotifierProvider.autoDispose
    .family<ReaderController, ReaderState, ReaderArgs>((ref, args) {
  final container = ref.container;
  return ReaderController(
    args: args,
    downloads: ref.watch(downloadServiceProvider),
    progress: ref.watch(progressRepositoryProvider),
    library: ref.watch(libraryRepositoryProvider),
    storage: ref.watch(storageServiceProvider),
    onClosed: () {
      // Library bars / Continue Reading pick up the new progress.
      container.invalidate(libraryProvider);
    },
    onTimeCounted: (seconds) =>
        container.read(readingGoalProvider.notifier).add(seconds),
  );
});

final dictionaryServiceProvider = Provider<DictionaryService>((ref) => DictionaryService());
