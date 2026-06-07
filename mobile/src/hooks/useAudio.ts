import { useCallback, useEffect, useRef } from 'react'
import * as Speech from 'expo-speech'
import { useAudioStore } from '@/store/audioStore'

/**
 * Splits a block of text into sentence-sized chunks.
 * expo-speech has a character limit (~4000 chars) on some platforms.
 */
function splitIntoChunks(text: string, maxChars = 300): string[] {
  const sentences = text
    .split(/(?<=[.!?])\s+/)
    .filter((s) => s.trim().length > 5)

  const chunks: string[] = []
  let current = ''

  for (const sentence of sentences) {
    if ((current + sentence).length > maxChars) {
      if (current) chunks.push(current.trim())
      current = sentence
    } else {
      current = current ? `${current} ${sentence}` : sentence
    }
  }

  if (current) chunks.push(current.trim())
  return chunks
}

export function useAudio() {
  const {
    text,
    isPlaying,
    currentSentenceIndex,
    speed,
    play,
    pause,
    stop,
    setSentenceIndex,
  } = useAudioStore()

  const chunksRef = useRef<string[]>([])
  const isMountedRef = useRef(true)

  useEffect(() => {
    chunksRef.current = splitIntoChunks(text)
    return () => {
      isMountedRef.current = false
    }
  }, [text])

  // ── Speak a single chunk ─────────────────────────────────────────────────

  const speakChunk = useCallback(
    (index: number) => {
      const chunks = chunksRef.current
      const chunk = chunks[index]
      if (!chunk) {
        // Finished all chunks
        stop()
        return
      }

      Speech.speak(chunk, {
        language: 'en',
        rate: speed,
        onDone: () => {
          if (!isMountedRef.current) return
          const next = index + 1
          setSentenceIndex(next)
          // Auto-advance if still playing
          if (useAudioStore.getState().isPlaying) {
            speakChunk(next)
          }
        },
        onStopped: () => {
          // Speech was stopped externally
        },
        onError: () => {
          if (isMountedRef.current) stop()
        },
      })
    },
    [speed, stop, setSentenceIndex],
  )

  // ── Controls ──────────────────────────────────────────────────────────────

  const handlePlay = useCallback(async () => {
    const isSpeaking = await Speech.isSpeakingAsync()
    if (isSpeaking) {
      await Speech.resume()
    } else {
      speakChunk(currentSentenceIndex)
    }
    play()
  }, [currentSentenceIndex, speakChunk, play])

  const handlePause = useCallback(async () => {
    await Speech.pause()
    pause()
  }, [pause])

  const handleStop = useCallback(async () => {
    await Speech.stop()
    stop()
  }, [stop])

  const handleSeek = useCallback(
    async (index: number) => {
      await Speech.stop()
      setSentenceIndex(index)
      if (isPlaying) speakChunk(index)
    },
    [isPlaying, setSentenceIndex, speakChunk],
  )

  // Stop speech when hook unmounts
  useEffect(() => {
    return () => {
      void Speech.stop()
      isMountedRef.current = false
    }
  }, [])

  return {
    handlePlay,
    handlePause,
    handleStop,
    handleSeek,
    chunks: chunksRef.current,
  }
}
