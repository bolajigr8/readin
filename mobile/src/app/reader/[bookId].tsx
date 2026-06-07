import React, { useCallback, useEffect, useRef, useState } from 'react'
import { Alert, StyleSheet, Text, TouchableOpacity, View } from 'react-native'
import { router, useLocalSearchParams } from 'expo-router'
import { StatusBar } from 'expo-status-bar'

import {
  ReaderWebView,
  type ReaderWebViewHandle,
} from '@/components/ReaderWebView'
import { ReaderToolbar } from '@/components/ReaderToolbar'
import { ChapterDrawer } from '@/components/ChapterDrawer'
import { ReaderSettings } from '@/components/ReaderSettings'
import { HighlightMenu } from '@/components/HighlightMenu'
import { NoteEditor } from '@/components/NoteEditor'
import { AnnotationsList } from '@/components/AnnotationsList'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useReader } from '@/hooks/useReader'
import { useReaderStore } from '@/store/readerStore'
import {
  useAnnotations,
  useCreateAnnotation,
  useDeleteAnnotation,
  type HighlightColor,
} from '@/hooks/useAnnotations'
import {
  useBookmarks,
  useCreateBookmark,
  useDeleteBookmark,
} from '@/hooks/useBookmarks'
import { toast } from '@/context/ToastContext'
import { THEME } from '@/constants/theme'

const TOOLBAR_HIDE_DELAY = 3500

// ── Reader is locked to dark theme ────────────────────────────────────────────
// epub.js theme injection via WebView messages is unreliable in Expo Go.
// The reader background and epub.js are both set to dark.
const READER_THEME = 'dark' as const
const READER_BG = '#0A0A0A'

export default function ReaderScreen() {
  // ── Route params ─────────────────────────────────────────────────────────
  const params = useLocalSearchParams<{ bookId: string }>()
  const bookId = Array.isArray(params.bookId)
    ? (params.bookId[0] ?? '')
    : (params.bookId ?? '')

  // ── Reader data hook ──────────────────────────────────────────────────────
  const {
    book,
    localEpubPath,
    initialCfi,
    downloadProgress,
    isLoading,
    error,
    savePendingProgress,
    flushProgress,
  } = useReader(bookId)

  // ── Store ─────────────────────────────────────────────────────────────────
  const {
    currentChapter,
    totalChapters,
    percentage,
    toc,
    isToolbarVisible,
    fontSize,
    fontFamily,
    setCurrentCfi,
    setChapter,
    setPercentage,
    setToc,
    toggleToolbar,
    showToolbar,
    setFontSize,
    setFontFamily,
    openBook,
    reset,
  } = useReaderStore()

  // ── Refs ──────────────────────────────────────────────────────────────────
  const webViewRef = useRef<ReaderWebViewHandle>(null)
  const toolbarTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  // ── Panel state ───────────────────────────────────────────────────────────
  const [isChapterDrawerOpen, setIsChapterDrawerOpen] = useState(false)
  const [isSettingsOpen, setIsSettingsOpen] = useState(false)
  const [showAnnotationList, setShowAnnotationList] = useState(false)

  // ── Highlight state ───────────────────────────────────────────────────────
  const [selectedText, setSelectedText] = useState('')
  const [selectedCfi, setSelectedCfi] = useState('')
  const [showHighlightMenu, setShowHighlightMenu] = useState(false)
  const [showNoteEditor, setShowNoteEditor] = useState(false)

  // ── Data hooks ────────────────────────────────────────────────────────────
  const { data: annotations = [] } = useAnnotations(bookId)
  const createAnnotation = useCreateAnnotation(bookId)
  const deleteAnnotation = useDeleteAnnotation(bookId)
  const { data: bookmarks = [] } = useBookmarks(bookId)
  const createBookmark = useCreateBookmark(bookId)
  // Declare deleteBookmark at component level — never inside a callback
  const deleteBookmark = useDeleteBookmark(bookId)

  // ── Init + cleanup ────────────────────────────────────────────────────────
  useEffect(() => {
    if (bookId) openBook(bookId)
    return () => {
      void flushProgress()
      reset()
    }
  }, [bookId, openBook, flushProgress, reset])

  // ── Toolbar auto-hide ─────────────────────────────────────────────────────
  const resetToolbarTimer = useCallback(() => {
    if (toolbarTimer.current) clearTimeout(toolbarTimer.current)
    toolbarTimer.current = setTimeout(() => {
      if (useReaderStore.getState().isToolbarVisible) {
        useReaderStore.getState().toggleToolbar()
      }
    }, TOOLBAR_HIDE_DELAY)
  }, [])

  useEffect(() => {
    if (isToolbarVisible) resetToolbarTimer()
    return () => {
      if (toolbarTimer.current) clearTimeout(toolbarTimer.current)
    }
  }, [isToolbarVisible, resetToolbarTimer])

  // ── Location change ───────────────────────────────────────────────────────
  const handleLocationChange = useCallback(
    (cfi: string, pct: number, chapterIndex: number, chapterTitle: string) => {
      if (cfi) {
        setCurrentCfi(cfi)
        setChapter(chapterIndex, chapterTitle, toc.length)
        savePendingProgress(cfi, pct, chapterIndex, chapterTitle, toc.length)
      }
      if (pct > 0) setPercentage(pct)
    },
    [setCurrentCfi, setChapter, setPercentage, savePendingProgress, toc.length],
  )

  // ── Tap — toggle toolbar ──────────────────────────────────────────────────
  const handleTap = useCallback(() => {
    if (toolbarTimer.current) clearTimeout(toolbarTimer.current)
    toggleToolbar()
    if (!isToolbarVisible) resetToolbarTimer()
  }, [toggleToolbar, isToolbarVisible, resetToolbarTimer])

  // ── Text selected ─────────────────────────────────────────────────────────
  const handleTextSelected = useCallback((text: string, cfi: string) => {
    if (text.trim().length === 0) return
    setSelectedText(text)
    setSelectedCfi(cfi)
    setShowHighlightMenu(true)
    if (toolbarTimer.current) clearTimeout(toolbarTimer.current)
  }, [])

  // ── Highlight ─────────────────────────────────────────────────────────────
  const handleHighlight = useCallback(
    async (color: HighlightColor) => {
      setShowHighlightMenu(false)
      try {
        const annotation = await createAnnotation.mutateAsync({
          type: 'highlight',
          cfiRange: selectedCfi,
          selectedText,
          color,
          chapterTitle: useReaderStore.getState().currentChapterTitle,
          chapterIndex: useReaderStore.getState().currentChapter,
        })
        webViewRef.current?.injectHighlight(selectedCfi, color, annotation._id)
        toast.success('Highlighted!')
      } catch {
        toast.error('Could not save highlight. Check your connection.')
      }
    },
    [selectedCfi, selectedText, createAnnotation],
  )

  // ── Save note ─────────────────────────────────────────────────────────────
  const handleSaveNote = useCallback(
    async (note: string) => {
      setShowNoteEditor(false)
      setShowHighlightMenu(false)
      try {
        const annotation = await createAnnotation.mutateAsync({
          type: 'note',
          cfiRange: selectedCfi,
          selectedText,
          note,
          color: 'yellow',
          chapterTitle: useReaderStore.getState().currentChapterTitle,
          chapterIndex: useReaderStore.getState().currentChapter,
        })
        webViewRef.current?.injectHighlight(
          selectedCfi,
          'yellow',
          annotation._id,
        )
        toast.success('Note saved!')
      } catch {
        toast.error('Could not save note.')
      }
    },
    [selectedCfi, selectedText, createAnnotation],
  )

  // ── Bookmark ──────────────────────────────────────────────────────────────
  const handleBookmark = useCallback(async () => {
    const cfi = useReaderStore.getState().currentCfi
    if (!cfi) {
      toast.info('Navigate to a page first.')
      return
    }
    const existing = bookmarks.find((b) => b.cfi === cfi)
    if (existing) {
      try {
        await deleteBookmark.mutateAsync(existing._id)
        toast.info('Bookmark removed.')
      } catch {
        toast.error('Could not remove bookmark.')
      }
      return
    }
    try {
      await createBookmark.mutateAsync({
        cfi,
        label:
          useReaderStore.getState().currentChapterTitle || 'Bookmarked page',
        chapterTitle: useReaderStore.getState().currentChapterTitle,
        chapterIndex: useReaderStore.getState().currentChapter,
        percentage: useReaderStore.getState().percentage,
      })
      toast.success('Bookmark added!')
    } catch {
      toast.error('Could not save bookmark.')
    }
  }, [bookmarks, createBookmark, deleteBookmark])

  // ── Font settings ─────────────────────────────────────────────────────────
  const handleFontSizeChange = (size: number) => {
    setFontSize(size)
    webViewRef.current?.setFontSize(size)
  }

  const handleFontFamilyChange = (family: 'serif' | 'sans-serif') => {
    setFontFamily(family)
    webViewRef.current?.setFontFamily(family)
  }

  // ── Chapter select ────────────────────────────────────────────────────────
  const handleChapterSelect = (cfi: string) => {
    webViewRef.current?.navigate(cfi)
    showToolbar()
    resetToolbarTimer()
  }

  // ── Error state ───────────────────────────────────────────────────────────
  // IMPORTANT: Go Back calls router.back() to actually navigate away,
  // AND reset() to clear reader store state.
  if (error) {
    return (
      <View style={[styles.centered, { backgroundColor: READER_BG }]}>
        <StatusBar style='light' />
        <Text style={styles.errorIcon}>{'📖'}</Text>
        <Text style={styles.errorTitle}>{'Could not open book'}</Text>
        <Text style={styles.errorMsg}>{error}</Text>
        <TouchableOpacity
          onPress={() => {
            reset()
            router.back()
          }}
          style={styles.retryBtn}
        >
          <Text style={styles.retryText}>{'Go Back'}</Text>
        </TouchableOpacity>
      </View>
    )
  }

  // ── Loading / download state ──────────────────────────────────────────────
  if (isLoading || !localEpubPath) {
    return (
      <View style={[styles.centered, { backgroundColor: READER_BG }]}>
        <StatusBar style='light' />
        <LoadingSpinner size='large' />
        <Text style={styles.loadingTitle}>
          {downloadProgress > 0 && downloadProgress < 100
            ? `Downloading... ${downloadProgress}%`
            : 'Preparing book...'}
        </Text>
        {downloadProgress > 0 && downloadProgress < 100 && (
          <View style={styles.downloadTrack}>
            <View
              style={[
                styles.downloadFill,
                { width: `${downloadProgress}%` as `${number}%` },
              ]}
            />
          </View>
        )}
      </View>
    )
  }

  // ── Reader ────────────────────────────────────────────────────────────────
  return (
    <View style={[styles.container, { backgroundColor: READER_BG }]}>
      <StatusBar style='light' />

      {/* EPUB WebView — always dark */}
      <ReaderWebView
        ref={webViewRef}
        epubPath={localEpubPath}
        initialCfi={initialCfi}
        fontSize={fontSize}
        fontFamily={fontFamily}
        theme={READER_THEME}
        onLocationChange={handleLocationChange}
        onTocReady={setToc}
        onTextSelected={handleTextSelected}
        onTap={handleTap}
        onReady={() => {
          // WebView and epub.js are ready
        }}
        onError={(msg: string) => {
          const isNetworkError =
            msg.toLowerCase().includes('fetch') ||
            msg.toLowerCase().includes('network') ||
            msg.toLowerCase().includes('load')

          toast.error(
            isNetworkError
              ? 'Could not load book. Internet is required on first open to load the reader engine.'
              : `Reader error: ${msg}`,
          )
        }}
      />

      {/* Toolbar overlay */}
      <ReaderToolbar
        title={book?.title ?? ''}
        currentChapter={currentChapter}
        totalChapters={totalChapters}
        percentage={percentage}
        isVisible={isToolbarVisible}
        bookId={bookId}
        onChaptersPress={() => {
          setIsChapterDrawerOpen(true)
          if (toolbarTimer.current) clearTimeout(toolbarTimer.current)
        }}
        onSettingsPress={() => {
          setIsSettingsOpen(true)
          if (toolbarTimer.current) clearTimeout(toolbarTimer.current)
        }}
        onAnnotationsPress={() => {
          setShowAnnotationList(true)
          if (toolbarTimer.current) clearTimeout(toolbarTimer.current)
        }}
        onNextChapter={() => webViewRef.current?.nextPage()}
        onPrevChapter={() => webViewRef.current?.prevPage()}
      />

      {/* Chapter drawer */}
      <ChapterDrawer
        toc={toc}
        currentChapter={currentChapter}
        isOpen={isChapterDrawerOpen}
        onClose={() => {
          setIsChapterDrawerOpen(false)
          resetToolbarTimer()
        }}
        onChapterSelect={handleChapterSelect}
      />

      {/* Settings sheet — font only, no theme */}
      <ReaderSettings
        isOpen={isSettingsOpen}
        onClose={() => {
          setIsSettingsOpen(false)
          resetToolbarTimer()
        }}
        fontSize={fontSize}
        fontFamily={fontFamily}
        onFontSizeChange={handleFontSizeChange}
        onFontFamilyChange={handleFontFamilyChange}
      />

      {/* Highlight menu */}
      <HighlightMenu
        isVisible={showHighlightMenu}
        selectedText={selectedText}
        onHighlight={(color) => void handleHighlight(color)}
        onAddNote={() => {
          setShowHighlightMenu(false)
          setShowNoteEditor(true)
        }}
        onDismiss={() => {
          setShowHighlightMenu(false)
          resetToolbarTimer()
        }}
      />

      {/* Note editor */}
      <NoteEditor
        isVisible={showNoteEditor}
        selectedText={selectedText}
        onSave={(note) => void handleSaveNote(note)}
        onCancel={() => {
          setShowNoteEditor(false)
          resetToolbarTimer()
        }}
      />

      {/* Annotations list */}
      <AnnotationsList
        annotations={annotations}
        isOpen={showAnnotationList}
        onClose={() => {
          setShowAnnotationList(false)
          resetToolbarTimer()
        }}
        onAnnotationPress={(a) => {
          webViewRef.current?.navigate(a.cfiRange)
          setShowAnnotationList(false)
        }}
        onDeleteAnnotation={(id) => void deleteAnnotation.mutateAsync(id)}
      />
    </View>
  )
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  centered: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 16,
    padding: 32,
  },
  loadingTitle: {
    fontFamily: 'Inter_400Regular',
    fontSize: 15,
    color: THEME.colors.text.secondary,
    marginTop: 8,
    textAlign: 'center',
  },
  downloadTrack: {
    width: 220,
    height: 4,
    backgroundColor: THEME.colors.border.default,
    borderRadius: 2,
    overflow: 'hidden',
  },
  downloadFill: {
    height: '100%',
    backgroundColor: THEME.colors.primary[500],
    borderRadius: 2,
  },
  errorIcon: { fontSize: 48 },
  errorTitle: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 20,
    color: THEME.colors.text.primary,
    textAlign: 'center',
  },
  errorMsg: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.secondary,
    textAlign: 'center',
    lineHeight: 20,
  },
  retryBtn: {
    paddingHorizontal: 32,
    paddingVertical: 14,
    backgroundColor: THEME.colors.surface,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: THEME.colors.border.light,
    marginTop: 8,
  },
  retryText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 16,
    color: THEME.colors.text.primary,
  },
})
