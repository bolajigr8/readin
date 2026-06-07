import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import api from '@/services/api'

export interface Bookmark {
  _id: string
  userId: string
  bookId: string
  cfi: string
  label: string
  chapterTitle: string
  chapterIndex: number
  percentage: number
  createdAt: string
}

const bookmarksKey = (bookId: string) => ['bookmarks', bookId] as const

export function useBookmarks(bookId: string) {
  return useQuery({
    queryKey: bookmarksKey(bookId),
    queryFn: async (): Promise<Bookmark[]> => {
      const res = await api.get(`/bookmarks/book/${bookId}`)
      return res.data.data as Bookmark[]
    },
    enabled: bookId.length > 0,
    staleTime: 1000 * 60 * 2,
  })
}

export function useCreateBookmark(bookId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (payload: {
      cfi: string
      label: string
      chapterTitle: string
      chapterIndex: number
      percentage: number
    }) => {
      const res = await api.post('/bookmarks', { ...payload, bookId })
      return res.data.data as Bookmark
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: bookmarksKey(bookId) })
    },
  })
}

export function useDeleteBookmark(bookId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => api.delete(`/bookmarks/${id}`),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: bookmarksKey(bookId) })
    },
  })
}
