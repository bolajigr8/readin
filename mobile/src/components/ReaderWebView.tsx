import React, { forwardRef, useImperativeHandle, useRef } from 'react'
import { StyleSheet } from 'react-native'
import { WebView } from 'react-native-webview'
import type { WebViewMessageEvent } from 'react-native-webview'
import type { TocItem } from '@/store/readerStore'

// ── Types ─────────────────────────────────────────────────────────────────────

interface ReaderWebViewProps {
  epubPath: string
  initialCfi?: string | null
  fontSize: number
  fontFamily: 'serif' | 'sans-serif'
  theme: 'light' | 'dark' | 'sepia'
  onLocationChange: (
    cfi: string,
    percentage: number,
    chapterIndex: number,
    chapterTitle: string,
  ) => void
  onTocReady: (toc: TocItem[]) => void
  onTextSelected: (selectedText: string, cfiRange: string) => void
  onTap: () => void
  onReady: () => void
  onError: (message: string) => void
}

export interface ReaderWebViewHandle {
  navigate: (cfi: string) => void
  nextPage: () => void
  prevPage: () => void
  setFontSize: (size: number) => void
  setFontFamily: (family: 'serif' | 'sans-serif') => void
  setTheme: (theme: 'light' | 'dark' | 'sepia') => void
  injectHighlight: (cfiRange: string, color: string, id: string) => void
}

// ── Theme config ──────────────────────────────────────────────────────────────

const THEMES = {
  light: { bg: '#FFFFFF', fg: '#1A1A1A', link: '#F97316' },
  dark: { bg: '#0A0A0A', fg: '#E4E4E7', link: '#FB923C' },
  sepia: { bg: '#F5E6C8', fg: '#3D2B1F', link: '#D97706' },
} as const

// ── HTML template ─────────────────────────────────────────────────────────────

function buildHTML(
  epubPath: string,
  initialCfi: string | null,
  fontSize: number,
  fontFamily: 'serif' | 'sans-serif',
  theme: 'light' | 'dark' | 'sepia',
): string {
  const t = THEMES[theme]
  const cfiArg = initialCfi ? `'${initialCfi}'` : 'undefined'

  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; background: ${t.bg}; }
    #viewer { width: 100%; height: 100%; position: absolute; top: 0; left: 0; }
    .epub-container { background: ${t.bg} !important; }
    .epub-view iframe { background: ${t.bg} !important; }
  </style>
</head>
<body>
  <div id="viewer"></div>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/epub.js/0.3.93/epub.min.js"></script>
  <script>
  (function() {
    'use strict';

    var book, rendition;
    var tocMap = {};

    function post(data) {
      try { window.ReactNativeWebView.postMessage(JSON.stringify(data)); } catch(e) {}
    }

    var THEMES = {
      light: { bg: '#FFFFFF', fg: '#1A1A1A' },
      dark:  { bg: '#0A0A0A', fg: '#E4E4E7' },
      sepia: { bg: '#F5E6C8', fg: '#3D2B1F' }
    };

    function applyTheme(name) {
      var t = THEMES[name] || THEMES.light;
      document.body.style.background = t.bg;
      if (!rendition) return;
      rendition.themes.register(name, {
        'body': { background: t.bg + ' !important', color: t.fg + ' !important' },
        'p':    { color: t.fg + ' !important' },
        'span': { color: t.fg + ' !important' },
        'h1,h2,h3,h4,h5,h6': { color: t.fg + ' !important' }
      });
      rendition.themes.select(name);
    }

    function applyFontSize(size) {
      if (rendition) rendition.themes.fontSize(size + 'px');
    }

    function applyFontFamily(family) {
      if (!rendition) return;
      var stack = family === 'serif'
        ? "Georgia, 'Times New Roman', serif"
        : "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
      rendition.themes.override('font-family', stack);
    }

    try {
      book = ePub('${epubPath}');
      rendition = book.renderTo('viewer', {
        width: window.innerWidth,
        height: window.innerHeight,
        spread: 'none',
        flow: 'paginated'
      });

      rendition.display(${cfiArg});

      rendition.hooks.content.register(function() {
        applyTheme('${theme}');
        applyFontSize(${fontSize});
        applyFontFamily('${fontFamily}');
      });

      rendition.on('locationChanged', function(loc) {
        var cfi = loc.start.cfi;
        post({
          type: 'LOCATION_CHANGE',
          cfi: cfi,
          chapterIndex: loc.start.index || 0,
          chapterTitle: tocMap[loc.start.href] || '',
          percentage: 0
        });
        book.locations.percentageFromCfi(cfi).then(function(pct) {
          post({ type: 'PERCENTAGE_UPDATE', percentage: Math.round((pct || 0) * 100) });
        });
      });

      book.loaded.navigation.then(function(nav) {
        nav.toc.forEach(function flatten(item) {
          tocMap[item.href] = item.label;
          if (item.subitems) item.subitems.forEach(flatten);
        });
        post({ type: 'TOC_READY', toc: nav.toc });
      });

      rendition.on('selected', function(cfiRange, contents) {
        var sel = contents.window.getSelection();
        if (sel && sel.toString().trim().length > 0) {
          post({ type: 'TEXT_SELECTED', selectedText: sel.toString(), cfiRange: cfiRange });
        }
      });

      rendition.on('tap', function() { post({ type: 'TAP' }); });

      book.ready.then(function() {
        return book.locations.generate(1600);
      }).then(function() {
        post({ type: 'LOCATIONS_READY' });
      });

      post({ type: 'BOOK_READY' });

    } catch(err) {
      post({ type: 'ERROR', message: err.message || 'Failed to load book' });
    }

    function handleCommand(raw) {
      try {
        var cmd = JSON.parse(raw);
        switch(cmd.type) {
          case 'NAVIGATE':      if (rendition) rendition.display(cmd.cfi); break;
          case 'NEXT_PAGE':     if (rendition) rendition.next(); break;
          case 'PREV_PAGE':     if (rendition) rendition.prev(); break;
          case 'SET_FONT_SIZE': applyFontSize(cmd.size); break;
          case 'SET_FONT_FAMILY': applyFontFamily(cmd.family); break;
          case 'SET_THEME':     applyTheme(cmd.theme); break;
          case 'ADD_HIGHLIGHT':
            if (rendition && cmd.cfiRange) {
              rendition.annotations.add(
                'highlight', cmd.cfiRange, {}, cmd.id, 'hl',
                { fill: cmd.color || '#F97316', 'fill-opacity': '0.3' }
              );
            }
            break;
        }
      } catch(e) {}
    }

    document.addEventListener('message', function(e) { handleCommand(e.data); });
    window.addEventListener('message', function(e) { handleCommand(e.data); });
  })();
  </script>
</body>
</html>`
}

// ── Component ─────────────────────────────────────────────────────────────────

export const ReaderWebView = forwardRef<
  ReaderWebViewHandle,
  ReaderWebViewProps
>(function ReaderWebView(
  {
    epubPath,
    initialCfi,
    fontSize,
    fontFamily,
    theme,
    onLocationChange,
    onTocReady,
    onTextSelected,
    onTap,
    onReady,
    onError,
  }: ReaderWebViewProps,
  ref: React.ForwardedRef<ReaderWebViewHandle>,
) {
  const webViewRef = useRef<WebView>(null)

  useImperativeHandle(ref, () => ({
    navigate: (cfi: string) => inject(`{"type":"NAVIGATE","cfi":"${cfi}"}`),
    nextPage: () => inject(`{"type":"NEXT_PAGE"}`),
    prevPage: () => inject(`{"type":"PREV_PAGE"}`),
    setFontSize: (size: number) =>
      inject(`{"type":"SET_FONT_SIZE","size":${size}}`),
    setFontFamily: (family: 'serif' | 'sans-serif') =>
      inject(`{"type":"SET_FONT_FAMILY","family":"${family}"}`),
    setTheme: (t: 'light' | 'dark' | 'sepia') =>
      inject(`{"type":"SET_THEME","theme":"${t}"}`),
    injectHighlight: (cfiRange: string, color: string, id: string) =>
      inject(JSON.stringify({ type: 'ADD_HIGHLIGHT', cfiRange, color, id })),
  }))

  function inject(json: string) {
    webViewRef.current?.injectJavaScript(
      `(function(){ window.postMessage(${JSON.stringify(json)},'*'); })(); true;`,
    )
  }

  const onMessage = (event: WebViewMessageEvent) => {
    try {
      const data = JSON.parse(event.nativeEvent.data) as Record<string, unknown>
      const type = data['type'] as string

      switch (type) {
        case 'BOOK_READY':
          onReady()
          break
        case 'LOCATION_CHANGE':
          onLocationChange(
            data['cfi'] as string,
            (data['percentage'] as number) ?? 0,
            (data['chapterIndex'] as number) ?? 0,
            (data['chapterTitle'] as string) ?? '',
          )
          break
        case 'PERCENTAGE_UPDATE':
          onLocationChange('', (data['percentage'] as number) ?? 0, 0, '')
          break
        case 'TOC_READY':
          onTocReady(data['toc'] as TocItem[])
          break
        case 'TEXT_SELECTED':
          onTextSelected(
            data['selectedText'] as string,
            data['cfiRange'] as string,
          )
          break
        case 'TAP':
          onTap()
          break
        case 'ERROR':
          onError(data['message'] as string)
          break
      }
    } catch {
      // ignore malformed messages
    }
  }

  const html = buildHTML(
    epubPath,
    initialCfi ?? null,
    fontSize,
    fontFamily,
    theme,
  )

  return (
    <WebView
      ref={webViewRef}
      style={styles.webView}
      source={{ html }}
      originWhitelist={['*']}
      allowFileAccess
      allowUniversalAccessFromFileURLs
      allowFileAccessFromFileURLs
      javaScriptEnabled
      domStorageEnabled
      showsVerticalScrollIndicator={false}
      showsHorizontalScrollIndicator={false}
      scrollEnabled={false}
      bounces={false}
      onMessage={onMessage}
      mixedContentMode='always'
    />
  )
})

const styles = StyleSheet.create({
  webView: { flex: 1, backgroundColor: 'transparent' },
})
