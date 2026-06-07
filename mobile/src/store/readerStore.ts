import { create } from 'zustand'

export interface TocItem {
  id: string
  href: string
  label: string
  subitems?: TocItem[]
}

interface ReaderState {
  currentBookId: string | null
  currentCfi: string | null
  currentChapter: number
  currentChapterTitle: string
  totalChapters: number
  percentage: number
  toc: TocItem[]
  isToolbarVisible: boolean
  fontSize: number
  fontFamily: 'serif' | 'sans-serif'
  theme: 'light' | 'dark' | 'sepia'
}

interface ReaderActions {
  setCurrentCfi: (cfi: string) => void
  setChapter: (index: number, title: string, total: number) => void
  setPercentage: (pct: number) => void
  setToc: (toc: TocItem[]) => void
  toggleToolbar: () => void
  showToolbar: () => void
  setFontSize: (size: number) => void
  setFontFamily: (family: 'serif' | 'sans-serif') => void
  setTheme: (theme: 'light' | 'dark' | 'sepia') => void
  openBook: (bookId: string) => void
  reset: () => void
}

const DEFAULT_STATE: ReaderState = {
  currentBookId: null,
  currentCfi: null,
  currentChapter: 0,
  currentChapterTitle: '',
  totalChapters: 0,
  percentage: 0,
  toc: [],
  isToolbarVisible: true,
  fontSize: 17,
  fontFamily: 'sans-serif',
  theme: 'dark',
}

export const useReaderStore = create<ReaderState & ReaderActions>((set) => ({
  ...DEFAULT_STATE,

  setCurrentCfi: (cfi) => set({ currentCfi: cfi }),

  setChapter: (index, title, total) =>
    set({
      currentChapter: index,
      currentChapterTitle: title,
      totalChapters: total,
    }),

  setPercentage: (pct) => set({ percentage: pct }),

  setToc: (toc) => set({ toc }),

  toggleToolbar: () =>
    set((state) => ({ isToolbarVisible: !state.isToolbarVisible })),

  showToolbar: () => set({ isToolbarVisible: true }),

  setFontSize: (size) => set({ fontSize: Math.min(28, Math.max(12, size)) }),

  setFontFamily: (fontFamily) => set({ fontFamily }),

  setTheme: (theme) => set({ theme }),

  openBook: (bookId) => set({ ...DEFAULT_STATE, currentBookId: bookId }),

  reset: () => set(DEFAULT_STATE),
}))
