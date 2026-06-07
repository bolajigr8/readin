// ── THE FIX: import from 'expo-file-system/legacy' ───────────────────────────
// In Expo SDK 54, the main expo-file-system API changed completely.
// getInfoAsync, documentDirectory, createDownloadResumable are now in /legacy.
// Using this import keeps ALL existing code working without any other changes.
import * as FileSystem from 'expo-file-system/legacy'

const EPUB_DIR = `${FileSystem.documentDirectory}epubs/`

/**
 * Ensure the epubs/ directory exists. Safe to call multiple times.
 */
async function ensureDir(): Promise<void> {
  const info = await FileSystem.getInfoAsync(EPUB_DIR)
  if (!info.exists) {
    await FileSystem.makeDirectoryAsync(EPUB_DIR, { intermediates: true })
  }
}

/**
 * Full local file:// path for a book's EPUB.
 */
export function getLocalEpubPath(bookId: string): string {
  return `${EPUB_DIR}${bookId}.epub`
}

/**
 * Returns true if the EPUB file exists locally and has content.
 */
export async function isEpubDownloaded(bookId: string): Promise<boolean> {
  try {
    const info = await FileSystem.getInfoAsync(getLocalEpubPath(bookId))
    return info.exists && 'size' in info && (info.size ?? 0) > 0
  } catch {
    return false
  }
}

/**
 * Download a book's EPUB from the given URL to local storage.
 * Returns the local file:// path on success.
 */
export async function downloadEpub(
  bookId: string,
  epubUrl: string,
  onProgress?: (progress: number) => void,
): Promise<string> {
  await ensureDir()
  const localPath = getLocalEpubPath(bookId)

  const downloadResumable = FileSystem.createDownloadResumable(
    epubUrl,
    localPath,
    {},
    (downloadProgress) => {
      const total = downloadProgress.totalBytesExpectedToWrite
      if (total > 0) {
        const progress = downloadProgress.totalBytesWritten / total
        onProgress?.(Math.round(progress * 100))
      }
    },
  )

  const result = await downloadResumable.downloadAsync()
  if (!result?.uri) {
    throw new Error('Download failed — no URI returned from server.')
  }

  return result.uri
}

/**
 * Delete a book's local EPUB. Called when the book is removed from library.
 */
export async function deleteLocalEpub(bookId: string): Promise<void> {
  try {
    const path = getLocalEpubPath(bookId)
    const info = await FileSystem.getInfoAsync(path)
    if (info.exists) {
      await FileSystem.deleteAsync(path, { idempotent: true })
    }
  } catch {
    console.warn('[epubStorage] Could not delete local EPUB for', bookId)
  }
}
