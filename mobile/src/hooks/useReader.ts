import { useCallback, useEffect, useRef, useState } from 'react'
import api from '@/services/api'
import {
  isEpubDownloaded,
  downloadEpub,
  getLocalEpubPath,
} from '@/utils/epubStorage'
import type { Book } from '@/types'

interface ReaderData {
  book: Book | null
  localEpubPath: string | null
  initialCfi: string | null
  downloadProgress: number
  isLoading: boolean
  error: string | null
}

export function useReader(bookId: string) {
  const [state, setState] = useState<ReaderData>({
    book: null,
    localEpubPath: null,
    initialCfi: null,
    downloadProgress: 0,
    isLoading: true,
    error: null,
  })

  const pendingProgress = useRef<{
    cfi: string
    percentage: number
    chapter: number
    chapterTitle: string
    totalChapters: number
  } | null>(null)

  const readingStartTime = useRef<number>(Date.now())
  const accumulatedSeconds = useRef<number>(0)

  useEffect(() => {
    let cancelled = false

    async function load() {
      try {
        setState((s) => ({ ...s, isLoading: true, error: null }))

        // Fetch book details
        const bookRes = await api.get(`/library/${bookId}`)
        const book = bookRes.data.data.book as Book

        // Fetch existing progress — don't fail if missing
        let initialCfi: string | null = null
        try {
          const progressRes = await api.get(`/progress/${bookId}`)
          const p = progressRes.data.data as {
            progress: { currentCfi: string } | null
          }
          initialCfi = p.progress?.currentCfi ?? null
        } catch {
          // No progress yet — fine, start from beginning
        }

        if (cancelled) return

        if (!book.convertedFileUrl) {
          throw new Error('This book has no EPUB file to read.')
        }

        // Try local file first
        const downloaded = await isEpubDownloaded(bookId)
        if (downloaded) {
          setState({
            book,
            localEpubPath: getLocalEpubPath(bookId),
            initialCfi,
            downloadProgress: 100,
            isLoading: false,
            error: null,
          })
          return
        }

        // Download
        setState((s) => ({ ...s, book, initialCfi, downloadProgress: 0 }))

        const localPath = await downloadEpub(
          bookId,
          book.convertedFileUrl,
          (pct) => {
            if (!cancelled) setState((s) => ({ ...s, downloadProgress: pct }))
          },
        )

        if (cancelled) return

        setState((s) => ({
          ...s,
          localEpubPath: localPath,
          downloadProgress: 100,
          isLoading: false,
        }))
      } catch (err) {
        if (!cancelled) {
          const message =
            err instanceof Error ? err.message : 'Failed to load book.'
          setState((s) => ({ ...s, isLoading: false, error: message }))
        }
      }
    }

    load()
    return () => {
      cancelled = true
    }
  }, [bookId])

  const savePendingProgress = useCallback(
    (
      cfi: string,
      percentage: number,
      chapter: number,
      chapterTitle: string,
      totalChapters: number,
    ) => {
      pendingProgress.current = {
        cfi,
        percentage,
        chapter,
        chapterTitle,
        totalChapters,
      }
    },
    [],
  )

  const flushProgress = useCallback(async () => {
    if (!pendingProgress.current) return

    const elapsed = Math.round((Date.now() - readingStartTime.current) / 1000)
    accumulatedSeconds.current += elapsed
    readingStartTime.current = Date.now()

    const p = pendingProgress.current
    pendingProgress.current = null

    try {
      await api.put(`/progress/${bookId}`, {
        currentCfi: p.cfi,
        percentage: p.percentage,
        currentChapter: p.chapter,
        currentChapterTitle: p.chapterTitle,
        totalChapters: p.totalChapters,
        readingTimeDeltaSeconds: accumulatedSeconds.current,
      })
      accumulatedSeconds.current = 0
    } catch {
      pendingProgress.current = p // restore so next flush retries
    }
  }, [bookId])

  useEffect(() => {
    const interval = setInterval(() => void flushProgress(), 30_000)
    return () => clearInterval(interval)
  }, [flushProgress])

  return { ...state, savePendingProgress, flushProgress }
}
