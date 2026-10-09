/// One table-of-contents entry (epub.js `nav.toc` item).
class TocItem {
  const TocItem({
    required this.id,
    required this.href,
    required this.label,
    this.subitems = const [],
  });

  final String id;
  final String href;
  final String label;
  final List<TocItem> subitems;

  factory TocItem.fromJson(Map<String, dynamic> j) {
    final subs = j['subitems'];
    return TocItem(
      id: (j['id'] ?? '').toString(),
      href: (j['href'] ?? '').toString(),
      label: (j['label'] ?? '').toString().trim(),
      subitems: subs is List
          ? subs
              .whereType<Map>()
              .map((e) => TocItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  /// `chapter.xhtml#id` → `chapter.xhtml`.
  String get baseHref => href.split('#').first;

  bool containsHref(String base) {
    if (baseHref == base || baseHref.endsWith('/$base') || base.endsWith('/$baseHref')) {
      return baseHref.isNotEmpty;
    }
    return subitems.any((s) => s.containsHref(base));
  }
}

List<TocItem> parseToc(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => TocItem.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// Index of the **top-level** TOC entry that contains [hrefBase]; `-1` if none.
/// (RN showed the spine index next to the TOC length: "Chapter 12 of 8".)
int tocIndexFor(List<TocItem> toc, String hrefBase) {
  if (hrefBase.isEmpty) return -1;
  for (var i = 0; i < toc.length; i++) {
    if (toc[i].containsHref(hrefBase)) return i;
  }
  return -1;
}

/// Saved reading position from `GET /progress/:bookId`.
class SavedProgress {
  const SavedProgress({
    required this.currentCfi,
    required this.percentage,
    required this.currentChapter,
    required this.totalChapters,
  });

  final String currentCfi;
  final double percentage;
  final int currentChapter;
  final int totalChapters;

  /// PDF positions are stored as `page:N`.
  int? get pdfPage {
    if (!currentCfi.startsWith('page:')) return null;
    final n = int.tryParse(currentCfi.substring(5));
    return (n == null || n < 1) ? null : n;
  }

  factory SavedProgress.fromJson(Map<String, dynamic> j) {
    num n(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);
    return SavedProgress(
      currentCfi: (j['currentCfi'] ?? '').toString(),
      percentage: n(j['percentage']).toDouble(),
      currentChapter: n(j['currentChapter']).toInt(),
      totalChapters: n(j['totalChapters']).toInt(),
    );
  }
}

/// Body of `PUT /progress/:bookId` (API_CONTRACT).
class ProgressPayload {
  const ProgressPayload({
    required this.currentCfi,
    required this.percentage,
    required this.currentChapter,
    required this.currentChapterTitle,
    required this.totalChapters,
  });

  final String currentCfi;

  /// Clamped to 0–100 when serialised.
  final double percentage;
  final int currentChapter;
  final String currentChapterTitle;
  final int totalChapters;

  Map<String, dynamic> toJson(int readingTimeDeltaSeconds) => {
        'currentCfi': currentCfi,
        'percentage': percentage.clamp(0.0, 100.0).toDouble(),
        'currentChapter': currentChapter < 0 ? 0 : currentChapter,
        'currentChapterTitle': currentChapterTitle,
        'totalChapters': totalChapters < 0 ? 0 : totalChapters,
        'readingTimeDeltaSeconds':
            readingTimeDeltaSeconds < 0 ? 0 : readingTimeDeltaSeconds,
      };
}

/// Reader preferences (persisted via `StorageService`).
class ReaderPrefs {
  const ReaderPrefs({
    required this.fontSize,
    required this.fontFamily,
    required this.theme,
    this.lineHeight = 1.6,
    this.margin = 16,
    this.align = 'left',
    this.flow = 'paged',
    this.brightness = 1.0,
    this.volumeKeys = true,
    this.warmth = 0.0,
    this.autoNight = false,
  });

  final double fontSize;

  /// `'sans-serif'` | `'serif'`.
  final String fontFamily;

  /// `'light'` | `'dark'` | `'sepia'` | `'night'`.
  final String theme;

  /// Line spacing multiplier (1.4 – 2.0).
  final double lineHeight;

  /// Horizontal margin in px.
  final double margin;

  /// `'left'` | `'justify'`.
  final String align;

  /// `'paged'` | `'scroll'`.
  final String flow;

  /// 1.0 = off … 0.3 = darkest (software dimmer).
  final double brightness;

  /// Volume buttons turn pages.
  final bool volumeKeys;

  /// Warm (amber) filter strength 0 – 0.5 (reduces blue light).
  final double warmth;

  /// Use the Night theme automatically in the evening.
  final bool autoNight;

  bool get isScroll => flow == 'scroll';

  ReaderPrefs copyWith({
    double? fontSize,
    String? fontFamily,
    String? theme,
    double? lineHeight,
    double? margin,
    String? align,
    String? flow,
    double? brightness,
    bool? volumeKeys,
    double? warmth,
    bool? autoNight,
  }) =>
      ReaderPrefs(
        fontSize: fontSize ?? this.fontSize,
        fontFamily: fontFamily ?? this.fontFamily,
        theme: theme ?? this.theme,
        lineHeight: lineHeight ?? this.lineHeight,
        margin: margin ?? this.margin,
        align: align ?? this.align,
        flow: flow ?? this.flow,
        brightness: brightness ?? this.brightness,
        volumeKeys: volumeKeys ?? this.volumeKeys,
        warmth: warmth ?? this.warmth,
        autoNight: autoNight ?? this.autoNight,
      );

  /// What the page needs for typography (no brightness / volume keys / flow).
  Map<String, dynamic> toPageJson() => {
        'fontSize': fontSize.round(),
        'fontFamily': fontFamily,
        'theme': theme,
        'lineHeight': lineHeight,
        'margin': margin.round(),
        'align': align,
      };

  @override
  bool operator ==(Object other) =>
      other is ReaderPrefs &&
      other.fontSize == fontSize &&
      other.fontFamily == fontFamily &&
      other.theme == theme &&
      other.lineHeight == lineHeight &&
      other.margin == margin &&
      other.align == align &&
      other.flow == flow &&
      other.brightness == brightness &&
      other.volumeKeys == volumeKeys &&
      other.warmth == warmth &&
      other.autoNight == autoNight;

  @override
  int get hashCode => Object.hash(
        fontSize, fontFamily, theme, lineHeight, margin, align, flow, brightness, volumeKeys,
        warmth, autoNight,
      );
}

/// "45 min" / "2h 10m" for the reading-time-left estimate.
String formatMinutes(int minutes) {
  if (minutes < 1) return '<1 min';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// One in-book search hit.
class SearchHit {
  const SearchHit({required this.cfi, required this.excerpt});

  final String cfi;
  final String excerpt;

  factory SearchHit.fromJson(Map<String, dynamic> j) => SearchHit(
        cfi: (j['cfi'] ?? '').toString(),
        excerpt: (j['excerpt'] ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim(),
      );
}
