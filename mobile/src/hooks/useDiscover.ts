import {
  useInfiniteQuery,
  useQuery,
  useQueryClient,
  useMutation,
} from '@tanstack/react-query'
import {
  searchBooks,
  browseBooks,
  getPopularBooks,
  getBook,
} from '@/services/gutendex'
import api from '@/services/api'
import type { GutenbergBook } from '@/services/gutendex'

// ── Popular books ─────────────────────────────────────────────────────────────

export function usePopularBooks() {
  return useInfiniteQuery({
    queryKey: ['discover', 'popular'],
    queryFn: ({ pageParam = 1 }) => getPopularBooks(pageParam as number),
    getNextPageParam: (last, all) =>
      last.next !== null ? all.length + 1 : undefined,
    initialPageParam: 1,
    staleTime: 1000 * 60 * 10, // 10 min — Gutenberg data rarely changes
  })
}

// ── Search ────────────────────────────────────────────────────────────────────

export function useSearchBooks(query: string) {
  return useInfiniteQuery({
    queryKey: ['discover', 'search', query],
    queryFn: ({ pageParam = 1 }) => searchBooks(query, pageParam as number),
    getNextPageParam: (last, all) =>
      last.next !== null ? all.length + 1 : undefined,
    initialPageParam: 1,
    enabled: query.trim().length >= 2,
    staleTime: 1000 * 60 * 5,
  })
}

// ── Browse by category ────────────────────────────────────────────────────────

export function useBrowseCategory(topic: string) {
  return useInfiniteQuery({
    queryKey: ['discover', 'browse', topic],
    queryFn: ({ pageParam = 1 }) => browseBooks(topic, pageParam as number),
    getNextPageParam: (last, all) =>
      last.next !== null ? all.length + 1 : undefined,
    initialPageParam: 1,
    enabled: topic.length > 0,
    staleTime: 1000 * 60 * 10,
  })
}

// ── Single book detail ────────────────────────────────────────────────────────

export function useGutenbergBook(id: number) {
  return useQuery({
    queryKey: ['gutenberg-book', id],
    queryFn: () => getBook(id),
    enabled: id > 0,
    staleTime: 1000 * 60 * 60, // 1 hour — book metadata never changes
  })
}

// ── Add to library ────────────────────────────────────────────────────────────

export function useAddToLibrary() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (book: GutenbergBook) => {
      const response = await api.post('/library/discover', {
        gutenbergId: String(book.id),
        title: book.title,
        author: book.authors.map((a) => a.name).join(', '),
        description: book.subjects.slice(0, 3).join('. '),
        coverUrl:
          book.formats['image/jpeg'] ??
          `https://www.gutenberg.org/cache/epub/${book.id}/pg${book.id}.cover.medium.jpg`,
        epubUrl:
          book.formats['application/epub+zip'] ??
          book.formats['application/epub'] ??
          '',
        language: book.languages[0] ?? 'en',
      })
      return response.data.data as { bookId: string; jobId: string }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['library'] })
    },
  })
}
