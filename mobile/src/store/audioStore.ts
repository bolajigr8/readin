import { create } from 'zustand'

interface AudioState {
  isPlaying: boolean
  bookId: string | null
  bookTitle: string | null
  coverUrl: string
  text: string
  currentSentenceIndex: number
  totalSentences: number
  speed: number
  isMiniPlayerVisible: boolean
}

interface AudioActions {
  loadBook: (
    bookId: string,
    bookTitle: string,
    coverUrl: string,
    text: string,
  ) => void
  play: () => void
  pause: () => void
  stop: () => void
  setSpeed: (speed: number) => void
  setSentenceIndex: (index: number) => void
  showMiniPlayer: () => void
  hideMiniPlayer: () => void
  reset: () => void
}

const DEFAULT: AudioState = {
  isPlaying: false,
  bookId: null,
  bookTitle: null,
  coverUrl: '',
  text: '',
  currentSentenceIndex: 0,
  totalSentences: 0,
  speed: 1.0,
  isMiniPlayerVisible: false,
}

export const useAudioStore = create<AudioState & AudioActions>((set) => ({
  ...DEFAULT,

  loadBook: (bookId, bookTitle, coverUrl, text) => {
    // Split text into sentences for tracking
    const sentences = text
      .split(/(?<=[.!?])\s+/)
      .filter((s) => s.trim().length > 5)

    set({
      bookId,
      bookTitle,
      coverUrl,
      text,
      currentSentenceIndex: 0,
      totalSentences: sentences.length,
      isPlaying: false,
      isMiniPlayerVisible: true,
    })
  },

  play: () => set({ isPlaying: true }),
  pause: () => set({ isPlaying: false }),
  stop: () => set({ isPlaying: false, isMiniPlayerVisible: false }),
  setSpeed: (speed) => set({ speed }),
  setSentenceIndex: (index) => set({ currentSentenceIndex: index }),
  showMiniPlayer: () => set({ isMiniPlayerVisible: true }),
  hideMiniPlayer: () => set({ isMiniPlayerVisible: false }),
  reset: () => set(DEFAULT),
}))
