import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../constants/app_colors.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/routes.dart';
import '../../../core/services/volume_keys.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/pressable_opacity.dart';
import '../../audio/providers/audio_controller.dart' show speedLabel;
import '../../ambient/ambient.dart';
import '../../annotations/data/annotation_models.dart';
import '../../annotations/providers/annotations_providers.dart';
import '../../notes/notes_export.dart';
import '../../notes/notes_screen.dart' show showExportSheet;
import '../../notes/quote_card.dart';
import '../../library/utils/relink.dart';
import '../providers/read_aloud_controller.dart';
import '../providers/reader_controller.dart';
import '../widgets/annotations_sheet.dart';
import '../widgets/chapter_drawer.dart';
import '../widgets/definition_sheet.dart';
import '../widgets/epub_view.dart';
import '../widgets/highlight_menu.dart';
import '../widgets/note_editor_sheet.dart';
import '../widgets/pdf_view.dart';
import '../widgets/reader_settings_sheet.dart';
import '../widgets/reader_toolbar.dart';
import '../widgets/tap_detector.dart';
import '../data/dictionary_service.dart';
import '../data/reader_models.dart';

const String _localToast =
    'Save to library to use highlights/notes/bookmarks/annotations.';

/// UI_SPEC §4.12 — the reader (EPUB via epub.js, PDF via pdfrx).
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.args});

  final ReaderArgs args;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  final EpubViewController _epub = EpubViewController();
  final PdfViewerController _pdf = PdfViewerController();

  EdgeInsets? _insets; // captured before immersive mode hides the bars
  Timer? _hideTimer;
  bool _lastImmersive = false;

  bool _tocOpen = false;
  bool _settingsOpen = false;
  bool _annotationsOpen = false;

  String _selText = '';
  String _selCfi = '';
  bool _menuVisible = false;
  bool _localToastShown = false;

  StreamSubscription<VolumeKey>? _volumeSub;
  bool _volumeOn = false;

  ProviderContainer? _container;
  int _autoLevel = 0;
  bool _nightNow = false;
  Timer? _nightTimer;

  /// Annotation ids already drawn in the page (re-drawn after every open).
  final Set<String> _applied = {};

  ReaderArgs get _args => widget.args;
  bool get _isLocal => _args.local != null;
  String get _annBookId => _isLocal ? '' : _args.bookId;

  ReaderController get _ctl => ref.read(readerControllerProvider(_args).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restartHideTimer();
    _container = ProviderScope.containerOf(context, listen: false);
    _nightNow = _isNight(DateTime.now());
    _nightTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final n = _isNight(DateTime.now());
      if (n == _nightNow || !mounted) return;
      setState(() => _nightNow = n);
      _applyTheme();
    });
    _volumeSub = VolumeKeys.presses.listen(_onVolumeKey);
    _setVolume(ref.read(readerControllerProvider(_args)).prefs.volumeKeys);
  }

  @override
  void deactivate() {
    // The element may be deactivated before it is disposed (route transition):
    // timers must stop NOW or they will look up ancestors of a dead element.
    _hideTimer?.cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _volumeSub?.cancel();
    _nightTimer?.cancel();
    VolumeKeys.disable();
    // Sounds and read-aloud end with the book.
    final c = _container;
    if (c != null) {
      c.read(ambientProvider.notifier).stopAll();
      if (c.exists(readAloudProvider)) c.read(readAloudProvider.notifier).stop();
    }
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    try {
      if (state == AppLifecycleState.paused) {
        unawaited(_ctl.onPause());
      } else if (state == AppLifecycleState.resumed) {
        _ctl.onResume();
      }
    } catch (_) {
      // reader already closed
    }
  }

  // ── toolbar / immersive ─────────────────────────────────────────────────────

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      if (_tocOpen || _settingsOpen || _annotationsOpen || _menuVisible) {
        _restartHideTimer(); // never hide while a panel is open
        return;
      }
      try {
        _ctl.setToolbar(false);
      } catch (_) {
        // widget is going away — nothing to hide
      }
    });
  }

  void _toggleToolbar() {
    final visible = ref.read(readerControllerProvider(_args)).toolbarVisible;
    _ctl.setToolbar(!visible);
  }

  void _applyImmersive(bool toolbarVisible) {
    final immersive = !toolbarVisible;
    if (immersive == _lastImmersive) return;
    _lastImmersive = immersive;
    SystemChrome.setEnabledSystemUIMode(
      immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  bool get _anyOverlay => _tocOpen || _settingsOpen || _annotationsOpen || _menuVisible;

  void _closeOverlays() {
    setState(() {
      _tocOpen = false;
      _settingsOpen = false;
      _annotationsOpen = false;
      _menuVisible = false;
    });
    _epub.clearSelection();
  }

  void _openPanel({bool toc = false, bool settings = false, bool annotations = false}) {
    setState(() {
      _tocOpen = toc;
      _settingsOpen = settings;
      _annotationsOpen = annotations;
      _menuVisible = false;
    });
    _ctl.setToolbar(true);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  // ── navigation ──────────────────────────────────────────────────────────────

  void _prevChapter(ReaderState s) {
    if (s.isPdf) {
      if (s.pdfPage > 1) _pdf.goToPage(pageNumber: s.pdfPage - 1);
    } else {
      _epub.prevSection();
    }
  }

  void _nextChapter(ReaderState s) {
    if (s.isPdf) {
      if (s.pdfPage < s.pdfPages) _pdf.goToPage(pageNumber: s.pdfPage + 1);
    } else {
      _epub.nextSection();
    }
  }

  // ── annotations ─────────────────────────────────────────────────────────────

  bool _requireAccount() {
    if (!_isLocal) return true;
    AppToast.info(_localToast);
    return false;
  }

  void _onTextSelected(String text, String cfiRange) {
    if (text.isEmpty || cfiRange.isEmpty) return;
    if (_isLocal) {
      if (!_localToastShown) {
        _localToastShown = true;
        AppToast.info(_localToast);
      }
      return;
    }
    setState(() {
      _selText = text;
      _selCfi = cfiRange;
      _menuVisible = true;
    });
  }

  void _dismissMenu() {
    setState(() => _menuVisible = false);
    _epub.clearSelection();
  }

  Future<void> _handleLimit(AppException e) async {
    final upgrade = await showConfirmDialog(
      context,
      title: 'Annotation Limit Reached',
      message: e.message,
      confirmLabel: 'Upgrade',
      cancelLabel: 'Not now',
    );
    if (upgrade && mounted) context.go(AppRoutes.profile);
  }

  Future<void> _highlight(HighlightColor color) async {
    final text = _selText;
    final cfi = _selCfi;
    if (cfi.isEmpty) return;
    final s = ref.read(readerControllerProvider(_args));
    setState(() => _menuVisible = false);

    final res = await ref.read(annotationsProvider(_annBookId).notifier).create(
          NewAnnotation(
            type: 'highlight',
            cfiRange: cfi,
            selectedText: text,
            color: color,
            chapterTitle: s.chapterTitle,
            chapterIndex: s.chapterIndex,
          ),
        );
    if (!mounted) return;
    final created = res.dataOrNull;
    if (created != null) {
      _epub.highlight(created.cfiRange, created.color.hex, created.id);
      _applied.add(created.id);
      _epub.clearSelection();
      AppToast.info('Highlighted!');
    } else if (res.exceptionOrNull?.statusCode == 403) {
      await _handleLimit(res.exceptionOrNull!);
    } else {
      AppToast.error('Could not save highlight.');
    }
  }

  Future<void> _addNote() async {
    final text = _selText;
    final cfi = _selCfi;
    if (cfi.isEmpty) return;
    final s = ref.read(readerControllerProvider(_args));
    setState(() => _menuVisible = false);

    final note = await showNoteEditor(context, selectedText: text);
    if (!mounted) return;
    if (note == null || note.isEmpty) {
      _epub.clearSelection();
      return;
    }

    final res = await ref.read(annotationsProvider(_annBookId).notifier).create(
          NewAnnotation(
            type: 'note',
            cfiRange: cfi,
            selectedText: text,
            note: note,
            chapterTitle: s.chapterTitle,
            chapterIndex: s.chapterIndex,
          ),
        );
    if (!mounted) return;
    final created = res.dataOrNull;
    if (created != null) {
      _epub.highlight(created.cfiRange, created.color.hex, created.id);
      _applied.add(created.id);
      _epub.clearSelection();
      AppToast.success('Note saved!');
    } else if (res.exceptionOrNull?.statusCode == 403) {
      await _handleLimit(res.exceptionOrNull!);
    } else {
      AppToast.error('Could not save note.');
    }
  }

  /// Tapping a drawn highlight opens its note (add / edit).
  Future<void> _onAnnotationClicked(String id) async {
    final notifier = ref.read(annotationsProvider(_annBookId).notifier);
    final list = ref.read(annotationsProvider(_annBookId)).items;
    Annotation? a;
    for (final x in list) {
      if (x.id == id) a = x;
    }
    if (a == null) return;

    final note = await showNoteEditor(
      context,
      selectedText: a.selectedText,
      initialNote: a.note,
    );
    if (!mounted || note == null || note == a.note) return;
    final res = await notifier.updateNote(a.id, note);
    if (!mounted) return;
    res.when(
      success: (_) => AppToast.success('Note saved!'),
      failure: (_) => AppToast.error('Could not save note.'),
    );
  }

  Future<void> _deleteAnnotation(Annotation a) async {
    _epub.removeHighlight(a.cfiRange);
    _applied.remove(a.id);
    final res = await ref.read(annotationsProvider(_annBookId).notifier).delete(a.id);
    if (!mounted) return;
    if (res.isFailure) {
      // Notifier restored the row; draw the highlight again.
      _epub.highlight(a.cfiRange, a.color.hex, a.id);
      _applied.add(a.id);
      AppToast.error('Could not delete annotation.');
    }
  }

  void _syncHighlights() {
    if (_isLocal) return;
    final s = ref.read(readerControllerProvider(_args));
    if (!s.engineReady || s.isPdf) return;
    final ann = ref.read(annotationsProvider(_annBookId));
    if (ann.isLoading) return;
    for (final a in ann.items) {
      if (_applied.add(a.id)) {
        _epub.highlight(a.cfiRange, a.color.hex, a.id);
      }
    }
  }

  // ── bookmarks ───────────────────────────────────────────────────────────────

  Future<void> _toggleBookmark() async {
    if (!_requireAccount()) return;
    final s = ref.read(readerControllerProvider(_args));
    final cfi = s.currentCfi;
    if (cfi == null || cfi.isEmpty) {
      AppToast.info('Navigate to a page first.');
      return;
    }
    final notifier = ref.read(bookmarksProvider(_annBookId).notifier);
    final existing = ref.read(bookmarksProvider(_annBookId)).byCfi(cfi);

    if (existing != null) {
      final res = await notifier.remove(existing.id);
      if (!mounted) return;
      res.when(
        success: (_) => AppToast.info('Bookmark removed.'),
        failure: (_) => AppToast.error('Could not remove bookmark.'),
      );
      return;
    }

    final label = s.isPdf
        ? 'Page ${s.pdfPage}'
        : (s.chapterTitle.isNotEmpty ? s.chapterTitle : 'Bookmark');
    final res = await notifier.add(
      NewBookmark(
        cfi: cfi,
        label: label,
        chapterTitle: s.chapterTitle,
        chapterIndex: s.isPdf ? s.pdfPage - 1 : s.chapterIndex,
        percentage: s.percentage.toDouble(),
      ),
    );
    if (!mounted) return;
    res.when(
      success: (_) => AppToast.success('Bookmark added!'),
      failure: (_) => AppToast.error('Could not save bookmark.'),
    );
  }

  void _openAnnotations() {
    if (!_requireAccount()) return;
    _openPanel(annotations: true);
  }

  void _jumpToBookmark(Bookmark b) {
    final s = ref.read(readerControllerProvider(_args));
    if (s.isPdf) {
      final n = int.tryParse(b.cfi.startsWith('page:') ? b.cfi.substring(5) : '');
      if (n != null) _pdf.goToPage(pageNumber: n);
    } else {
      _epub.display(b.cfi);
    }
    _closeOverlays();
  }

  // ── volume buttons / search / dictionary / scrubber ─────────────────────────

  void _setVolume(bool on) {
    if (on == _volumeOn) return;
    _volumeOn = on;
    on ? VolumeKeys.enable() : VolumeKeys.disable();
  }

  /// Volume up = previous page, volume down = next page.
  void _onVolumeKey(VolumeKey key) {
    if (!mounted || _anyOverlay) return;
    final s = ref.read(readerControllerProvider(_args));
    if (s.phase != ReaderPhase.ready || !s.engineReady || !s.prefs.volumeKeys) return;
    HapticFeedback.selectionClick();
    final forward = key == VolumeKey.down;
    if (s.isPdf) {
      final n = s.pdfPage + (forward ? 1 : -1);
      if (n >= 1 && n <= s.pdfPages) _pdf.goToPage(pageNumber: n);
    } else {
      forward ? _epub.next() : _epub.prev();
    }
  }

  void _search(String query) {
    _ctl.beginSearch(query);
    final q = query.trim();
    if (q.length >= 2) _epub.search(q);
  }

  void _seek(ReaderState s, double fraction) {
    if (s.isPdf) {
      if (s.pdfPages < 1) return;
      final n = (fraction * s.pdfPages).round().clamp(1, s.pdfPages).toInt();
      _pdf.goToPage(pageNumber: n);
    } else {
      _epub.seekPercent(fraction);
    }
  }

  void _copySelection() {
    final text = _selText;
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _menuVisible = false);
    _epub.clearSelection();
    AppToast.info('Copied to clipboard');
  }

  Future<void> _define() async {
    final word = cleanWord(_selText);
    if (word == null) return;
    setState(() => _menuVisible = false);
    _epub.clearSelection();
    await showDefinitionSheet(
      context,
      word: word,
      service: ref.read(dictionaryServiceProvider),
    );
  }

  // ── night theme / auto-scroll / read aloud / quote card / export ─────────────

  static bool _isNight(DateTime t) => t.hour >= 20 || t.hour < 6;

  /// The prefs the page shows: Night theme in the evening when "Auto Night" is on.
  ReaderPrefs _effective(ReaderPrefs p) =>
      p.autoNight && _nightNow ? p.copyWith(theme: 'night') : p;

  void _applyTheme() {
    final p = ref.read(readerControllerProvider(_args)).prefs;
    _epub.setTheme(_effective(p));
  }

  void _setAutoLevel(int level) {
    setState(() => _autoLevel = level);
    _epub.autoScroll(level);
  }

  void _toggleReadAloud() {
    final ra = ref.read(readAloudProvider.notifier);
    if (ref.read(readAloudProvider).active) {
      ra.stop();
      return;
    }
    final s = ref.read(readerControllerProvider(_args));
    ra.attach(_epub, s.title);
    _setAutoLevel(0);
    ra.start();
    setState(() => _settingsOpen = false);
  }

  Future<void> _shareCard() async {
    final text = _selText;
    if (text.isEmpty) return;
    final s = ref.read(readerControllerProvider(_args));
    setState(() => _menuVisible = false);
    _epub.clearSelection();
    await showQuoteCardSheet(
      context,
      quote: text,
      bookTitle: s.title,
      author: _args.book?.author ?? '',
    );
  }

  void _exportBook() {
    final s = ref.read(readerControllerProvider(_args));
    final items = ref.read(annotationsProvider(_annBookId)).items;
    if (items.isEmpty) return;
    final group = NoteGroup(
      bookId: _args.bookId,
      title: s.title,
      author: _args.book?.author ?? '',
      items: items,
    );
    showExportSheet(
      context,
      [group],
      fileName: s.title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim().replaceAll(' ', '-'),
    );
  }

  // ── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _insets ??= MediaQuery.viewPaddingOf(context);
    final insets = _insets!;

    final s = ref.watch(readerControllerProvider(_args));
    final ann = ref.watch(annotationsProvider(_annBookId));
    final bms = ref.watch(bookmarksProvider(_annBookId));

    // Settings → page (no reload).
    ref.listen<ReaderPrefs>(
      readerControllerProvider(_args).select((x) => x.prefs),
      (prev, next) {
        if (prev == next) return;
        _epub.setTheme(_effective(next));
        if (prev != null && prev.flow != next.flow) _epub.setFlow(next.flow);
        _setVolume(next.volumeKeys);
      },
    );
    // Toolbar visibility → immersive mode + auto-hide timer.
    ref.listen<bool>(
      readerControllerProvider(_args).select((x) => x.toolbarVisible),
      (prev, next) {
        _applyImmersive(next);
        if (next) _restartHideTimer();
      },
    );
    // Draw saved highlights once the book is displayed and annotations loaded.
    ref.listen(readerControllerProvider(_args).select((x) => x.engineReady),
        (prev, next) {
      if (next) _syncHighlights();
    });
    ref.listen(annotationsProvider(_annBookId), (prev, next) => _syncHighlights());

    final palette = ReaderPalette.byName(_effective(s.prefs).theme);
    final bg = s.phase == ReaderPhase.ready ? palette.bg : AppColors.background;

    return PopScope(
      canPop: !_anyOverlay,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeOverlays();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: bg,
          body: switch (s.phase) {
            ReaderPhase.loading => _LoadingBody(state: s),
            ReaderPhase.error => _ErrorBody(
                message: s.error ?? 'Could not open this book.',
                detail: s.errorDetail,
                canRedownload: s.canRedownload,
                onRelink: s.canRelink && _args.book != null
                    ? () async {
                        if (await relinkBookFile(context, ref, _args.book!)) _ctl.reopen();
                      }
                    : null,
                onBack: _goBack,
                onRedownload: () => _ctl.redownload(),
              ),
            ReaderPhase.ready => _buildReady(context, s, ann, bms, insets, palette),
          },
        ),
      ),
    );
  }

  Widget _buildReady(
    BuildContext context,
    ReaderState s,
    AnnotationsState ann,
    BookmarksState bms,
    EdgeInsets insets,
    ReaderPalette palette,
  ) {
    final path = s.filePath!;
    final centerLabel = s.isPdf
        ? (s.pdfPages > 0 ? 'Page ${s.pdfPage} of ${s.pdfPages}' : 'Reading...')
        : (s.toc.isNotEmpty && s.engineReady
            ? 'Chapter ${s.chapterIndex + 1} of ${s.toc.length}'
            : 'Reading...');
    final navEnabled = s.isPdf ? s.pdfPages > 0 : s.toc.isNotEmpty;
    final bookmarked = bms.byCfi(s.currentCfi) != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Page content, clear of the system bars (constant size in immersive).
        Padding(
          padding: EdgeInsets.fromLTRB(0, insets.top, 0, insets.bottom),
          child: s.isPdf
              ? TapDetector(
                  onTap: (_) => _toggleToolbar(),
                  child: PdfReaderView(
                    path: path,
                    controller: _pdf,
                    initialPage: s.initialPage,
                    backgroundColor: palette.bg,
                    onReady: _ctl.onPdfReady,
                    onPage: _ctl.onPdfPage,
                    onError: (m) => _ctl.onEngineError(m),
                  ),
                )
              : EpubView(
                  path: path,
                  controller: _epub,
                  initialCfi: s.initialCfi,
                  prefs: _effective(s.prefs),
                  backgroundColor: palette.bg,
                  onReady: _ctl.onEpubReady,
                  onToc: _ctl.onToc,
                  onLocation: _ctl.onEpubLocation,
                  onTextSelected: _onTextSelected,
                  onTap: _toggleToolbar,
                  onAnnotationClicked: _onAnnotationClicked,
                  onLocationsReady: _ctl.onLocationsReady,
                  onSearchResults: _ctl.onSearchResults,
                  onTtsSentences: (items, start) =>
                      ref.read(readAloudProvider.notifier).onSentences(items, start),
                  onError: (m) {
                    final fatal = _ctl.onEngineError(m);
                    if (!fatal) AppToast.error(m);
                  },
                ),
        ),

        // Warm (blue-light) filter.
        if (s.prefs.warmth > 0.001)
          IgnorePointer(
            child: ColoredBox(
              color: AppColors.primary500.withValues(alpha: s.prefs.warmth * 0.9),
            ),
          ),

        // Software dimmer (never blocks touches).
        if (s.prefs.brightness < 0.999)
          IgnorePointer(
            child: ColoredBox(
              color: AppColors.black.withValues(alpha: 1 - s.prefs.brightness),
            ),
          ),

        if (!s.engineReady)
          const IgnorePointer(
            child: _OpeningOverlay(),
          ),

        ReaderToolbar(
          title: s.title,
          visible: s.toolbarVisible,
          insets: insets,
          centerLabel: centerLabel,
          percentage: s.percentage,
          timeLeft: s.minutesLeft == null ? null : '~${formatMinutes(s.minutesLeft!)} left',
          scrubEnabled: s.isPdf ? s.pdfPages > 1 : s.locationsReady,
          onSeek: (f) => _seek(s, f),
          navEnabled: navEnabled,
          bookmarked: bookmarked,
          onBack: _goBack,
          onBookmark: _toggleBookmark,
          onAnnotations: _openAnnotations,
          onChapters: () {
            if (s.isPdf) {
              AppToast.warning('Table of contents not available for PDFs.');
            } else {
              _openPanel(toc: true);
            }
          },
          onSettings: () => _openPanel(settings: true),
          onPrev: () => _prevChapter(s),
          onNext: () => _nextChapter(s),
        ),

        HighlightMenu(
          isVisible: _menuVisible,
          selectedText: _selText,
          onHighlight: _highlight,
          onAddNote: _addNote,
          onCopy: _copySelection,
          onShareCard: _shareCard,
          onDefine: cleanWord(_selText) == null ? null : _define,
          onDismiss: _dismissMenu,
        ),

        ChapterDrawer(
          toc: s.toc,
          currentChapter: s.chapterIndex,
          isOpen: _tocOpen,
          onClose: () => setState(() => _tocOpen = false),
          onSelect: _epub.display,
          searchQuery: s.searchQuery,
          searchResults: s.searchResults,
          isSearching: s.isSearching,
          onSearch: _search,
          onClearSearch: _ctl.clearSearch,
          onResult: (hit) => _epub.display(hit.cfi),
        ),

        AnnotationsSheet(
          isOpen: _annotationsOpen,
          onClose: () => setState(() => _annotationsOpen = false),
          annotations: ann.items,
          bookmarks: bms.items,
          showHighlightsTab: !s.isPdf,
          onAnnotation: (a) {
            _epub.display(a.cfiRange);
            setState(() => _annotationsOpen = false);
          },
          onDeleteAnnotation: _deleteAnnotation,
          onBookmark: _jumpToBookmark,
          onExport: _exportBook,
          onDeleteBookmark: (b) async {
            final res = await ref.read(bookmarksProvider(_annBookId).notifier).remove(b.id);
            if (!mounted) return;
            if (res.isFailure) AppToast.error('Could not remove bookmark.');
          },
        ),

        ReaderSettingsSheet(
          isOpen: _settingsOpen,
          onClose: () => setState(() => _settingsOpen = false),
          prefs: s.prefs,
          showPageLayout: !s.isPdf,
          onFontSize: _ctl.setFontSize,
          onFontFamily: _ctl.setFontFamily,
          onTheme: _ctl.setTheme,
          onLineHeight: _ctl.setLineHeight,
          onMargin: _ctl.setMargin,
          onAlign: _ctl.setAlign,
          onFlow: _ctl.setFlow,
          onBrightness: _ctl.setBrightness,
          onVolumeKeys: _ctl.setVolumeKeys,
          onWarmth: _ctl.setWarmth,
          onAutoNight: (v) {
            _ctl.setAutoNight(v);
            _applyTheme();
          },
          autoScrollLevel: _autoLevel,
          onAutoScroll: _setAutoLevel,
          onOpenSounds: () => showAmbientSheet(context),
          readAloudActive: ref.watch(readAloudProvider).active,
          onReadAloud: _toggleReadAloud,
        ),

        // Auto-scroll indicator (tap to stop).
        if (_autoLevel > 0)
          Positioned(
            top: insets.top + 10,
            right: 16,
            child: PressableOpacity(
              pressedOpacity: 0.8,
              semanticLabel: 'Stop auto-scroll',
              onTap: () => _setAutoLevel(0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary500),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Ionicons.play_forward_outline, size: 14, color: AppColors.primary500),
                    const SizedBox(width: 6),
                    Text(
                      'Auto ${const ['', 'slow', 'medium', 'fast'][_autoLevel]}  ✕',
                      style: AppTypography.label(size: 12, weight: FontWeight.w600, color: AppColors.primary500),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Read-aloud controls.
        if (ref.watch(readAloudProvider).active)
          Positioned(
            left: 16,
            right: 16,
            bottom: insets.bottom + 132,
            child: _ReadAloudBar(
              state: ref.watch(readAloudProvider),
              onPrev: () => ref.read(readAloudProvider.notifier).skip(-1),
              onNext: () => ref.read(readAloudProvider.notifier).skip(1),
              onToggle: () {
                final c = ref.read(readAloudProvider.notifier);
                ref.read(readAloudProvider).playing ? c.pause() : c.resume();
              },
              onSpeed: () {
                const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
                final cur = ref.read(readAloudProvider).speed;
                final next = speeds[(speeds.indexOf(cur) + 1) % speeds.length];
                ref.read(readAloudProvider.notifier).setSpeed(next);
              },
              onStop: () => ref.read(readAloudProvider.notifier).stop(),
            ),
          ),
      ],
    );
  }
}

class _OpeningOverlay extends StatelessWidget {
  const _OpeningOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary500),
            ),
            const SizedBox(height: 12),
            Text(
              'Opening book...',
              style: AppTypography.label(size: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.state});

  final ReaderState state;

  @override
  Widget build(BuildContext context) {
    final downloading = state.isDownloading;
    final p = state.downloadProgress;
    final label = downloading
        ? (p == null ? 'Downloading...' : 'Downloading... ${(p * 100).round()}%')
        : 'Preparing book...';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary500),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: AppTypography.label(size: 14, color: AppColors.textSecondary),
          ),
          if (downloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                width: 220,
                height: 4,
                child: LinearProgressIndicator(
                  value: p,
                  backgroundColor: AppColors.borderDefault,
                  color: AppColors.primary500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.canRedownload,
    required this.onBack,
    this.detail,
    this.onRelink,
    required this.onRedownload,
  });

  final String message;
  final String? detail;
  final bool canRedownload;
  final VoidCallback onBack;
  final VoidCallback onRedownload;
  final VoidCallback? onRelink;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📖', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Could not open book',
              style: AppTypography.label(size: 20, weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.label(
                size: 13,
                color: AppColors.textSecondary,
                lineHeight: 19,
              ),
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Details: $detail',
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(size: 11, color: AppColors.textMuted, lineHeight: 15),
              ),
            ],
            const SizedBox(height: 24),
            if (onRelink != null) ...[
              PressableOpacity(
                pressedOpacity: 0.85,
                onTap: onRelink,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary500,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Choose the file',
                    style: AppTypography.label(size: 16, weight: FontWeight.w600, color: AppColors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (canRedownload) ...[
              PressableOpacity(
                pressedOpacity: 0.85,
                onTap: onRedownload,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary500,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Re-download',
                    style: AppTypography.label(
                      size: 16,
                      weight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            PressableOpacity(
              pressedOpacity: 0.8,
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  'Go Back',
                  style: AppTypography.label(size: 16, weight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact player shown while the book is being read aloud.
class _ReadAloudBar extends StatelessWidget {
  const _ReadAloudBar({
    required this.state,
    required this.onPrev,
    required this.onNext,
    required this.onToggle,
    required this.onSpeed,
    required this.onStop,
  });

  final ReadAloudState state;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToggle;
  final VoidCallback onSpeed;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, String label, VoidCallback t, {double size = 22, Color? color}) =>
        PressableOpacity(
          pressedOpacity: 0.7,
          semanticLabel: label,
          onTap: t,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(i, size: size, color: color ?? AppColors.textPrimary),
          ),
        );

    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            btn(Ionicons.play_skip_back_outline, 'Previous sentence', onPrev),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: AppColors.primary500, shape: BoxShape.circle),
              child: PressableOpacity(
                pressedOpacity: 0.8,
                semanticLabel: state.playing ? 'Pause' : 'Play',
                onTap: onToggle,
                child: Icon(
                  state.playing ? Ionicons.pause : Ionicons.play,
                  size: 22,
                  color: AppColors.white,
                ),
              ),
            ),
            btn(Ionicons.play_skip_forward_outline, 'Next sentence', onNext),
            Expanded(
              child: Text(
                state.total == 0 ? 'Preparing...' : '${state.index + 1} / ${state.total}',
                textAlign: TextAlign.center,
                style: AppTypography.label(size: 12, color: AppColors.textMuted),
              ),
            ),
            PressableOpacity(
              pressedOpacity: 0.75,
              semanticLabel: 'Speed',
              onTap: onSpeed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Text(
                  speedLabel(state.speed),
                  style: AppTypography.label(size: 12, weight: FontWeight.w600, color: AppColors.primary500),
                ),
              ),
            ),
            btn(Ionicons.close, 'Stop reading', onStop, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
