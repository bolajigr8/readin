import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import api from '@/services/api'

export type HighlightColor = 'yellow' | 'green' | 'blue' | 'pink' | 'purple'

export interface Annotation {
  _id: string
  userId: string
  bookId: string
  type: 'highlight' | 'note'
  cfiRange: string
  selectedText: string
  note?: string
  color: HighlightColor
  chapterTitle: string
  chapterIndex: number
  createdAt: string
}

// ── Query key ─────────────────────────────────────────────────────────────────
const annotationsKey = (bookId: string) => ['annotations', bookId] as const

// ── Fetch all annotations for a book ─────────────────────────────────────────
export function useAnnotations(bookId: string) {
  return useQuery({
    queryKey: annotationsKey(bookId),
    queryFn: async (): Promise<Annotation[]> => {
      const res = await api.get(`/annotations/book/${bookId}`)
      return res.data.data as Annotation[]
    },
    enabled: bookId.length > 0,
    staleTime: 1000 * 60 * 2,
  })
}

// ── Create annotation ─────────────────────────────────────────────────────────
export function useCreateAnnotation(bookId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (payload: {
      type: 'highlight' | 'note'
      cfiRange: string
      selectedText: string
      note?: string
      color: HighlightColor
      chapterTitle: string
      chapterIndex: number
    }) => {
      const res = await api.post('/annotations', { ...payload, bookId })
      return res.data.data as Annotation
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: annotationsKey(bookId) })
    },
  })
}

// ── Update annotation ─────────────────────────────────────────────────────────
export function useUpdateAnnotation(bookId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({
      id,
      note,
      color,
    }: {
      id: string
      note?: string
      color?: HighlightColor
    }) => {
      const res = await api.put(`/annotations/${id}`, { note, color })
      return res.data.data as Annotation
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: annotationsKey(bookId) })
    },
  })
}

// ── Delete annotation ─────────────────────────────────────────────────────────
export function useDeleteAnnotation(bookId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => api.delete(`/annotations/${id}`),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: annotationsKey(bookId) })
    },
  })
}
