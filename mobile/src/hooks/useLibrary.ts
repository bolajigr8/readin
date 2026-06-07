import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import api from '@/services/api'
import type { Book, LibraryResponse } from '@/types'

// Shared query key — used to invalidate library after upload completes
export const LIBRARY_QUERY_KEY = ['library'] as const

// ── useLibrary ────────────────────────────────────────────────────────────────

export function useLibrary() {
  return useQuery({
    queryKey: LIBRARY_QUERY_KEY,
    queryFn: async (): Promise<LibraryResponse> => {
      const response = await api.get('/library')
      // Backend returns { success, message, data: { books, meta } }
      return response.data.data as LibraryResponse
    },
    staleTime: 1000 * 60 * 2, // consider fresh for 2 minutes
  })
}

// ── useBook ───────────────────────────────────────────────────────────────────

export function useBook(bookId: string) {
  return useQuery({
    queryKey: ['book', bookId],
    queryFn: async () => {
      const response = await api.get(`/library/${bookId}`)
      return response.data.data as {
        book: Book
        progress: unknown
        annotationCount: number
      }
    },
    enabled: bookId.length > 0,
  })
}

// ── useDeleteBook ─────────────────────────────────────────────────────────────

export function useDeleteBook() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (bookId: string) => api.delete(`/library/${bookId}`),
    onSuccess: () => {
      // Immediately remove from cache so the UI updates without waiting
      queryClient.invalidateQueries({ queryKey: LIBRARY_QUERY_KEY })
    },
  })
}

// ── useContinueReading ────────────────────────────────────────────────────────
// Returns top 3 books the user is currently reading (progress > 0 and < 99%)
// sorted by most recently read

export function useContinueReading(): Book[] {
  const { data } = useLibrary()
  if (!data?.books) return []

  return data.books
    .filter(
      (book) =>
        book.status === 'ready' &&
        book.progress !== null &&
        book.progress !== undefined &&
        book.progress.percentage > 0 &&
        book.progress.percentage < 99 &&
        !book.progress.isCompleted,
    )
    .sort((a, b) => {
      const aTime = a.progress?.lastReadAt ?? a.updatedAt
      const bTime = b.progress?.lastReadAt ?? b.updatedAt
      return new Date(bTime).getTime() - new Date(aTime).getTime()
    })
    .slice(0, 3)
}
