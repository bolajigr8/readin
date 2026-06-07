import { useCallback, useRef } from 'react'
import * as DocumentPicker from 'expo-document-picker'
import { useQueryClient } from '@tanstack/react-query'
import api from '@/services/api'
import { useLibraryStore } from '@/store/libraryStore'
import { LIBRARY_QUERY_KEY } from './useLibrary'
import type { ActiveUpload, JobStatus } from '@/types'

const POLL_INTERVAL_MS = 3000
const MAX_POLL_ATTEMPTS = 120 // 6 minutes

const ACCEPTED_TYPES = [
  'application/pdf',
  'application/epub+zip',
  'application/x-mobipocket-ebook',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain',
]

export function useUpload() {
  const queryClient = useQueryClient()
  const { addUpload, updateUpload, removeUpload } = useLibraryStore()
  const pollRefs = useRef<Map<string, ReturnType<typeof setInterval>>>(
    new Map(),
  )

  const stopPolling = useCallback((jobId: string) => {
    const handle = pollRefs.current.get(jobId)
    if (handle !== undefined) {
      clearInterval(handle)
      pollRefs.current.delete(jobId)
    }
  }, [])

  const startPolling = useCallback(
    (jobId: string) => {
      let attempts = 0

      const handle = setInterval(async () => {
        attempts += 1

        try {
          const response = await api.get(`/files/job/${jobId}`)
          const job = response.data.data as JobStatus

          // ── Map backend status → ActiveUpload status ────────────────────
          // These are DIFFERENT enums. JobStatus uses "completed"/"waiting"/"active".
          // ActiveUpload uses "ready"/"queued"/"converting". Map them explicitly.
          const uploadStatus: ActiveUpload['status'] =
            job.status === 'completed'
              ? 'ready'
              : job.status === 'failed'
                ? 'failed'
                : job.status === 'active'
                  ? 'converting'
                  : 'queued'

          // ── Build the update with correct type ──────────────────────────
          // Use Partial<ActiveUpload> directly — avoids the intersection type conflict
          const update: Partial<ActiveUpload> = {
            status: uploadStatus,
            progress: job.progress,
          }

          // Only add error field when it's a real string (not undefined)
          if (typeof job.error === 'string') {
            update.error = job.error
          }

          updateUpload(jobId, update)

          // Terminal states
          if (job.status === 'completed' || job.status === 'failed') {
            stopPolling(jobId)

            if (job.status === 'completed') {
              queryClient.invalidateQueries({ queryKey: LIBRARY_QUERY_KEY })
            }

            setTimeout(() => removeUpload(jobId), 2500)
            return
          }

          if (attempts >= MAX_POLL_ATTEMPTS) {
            stopPolling(jobId)
            updateUpload(jobId, {
              status: 'failed',
              error: 'Conversion timed out. Please try again.',
            })
            setTimeout(() => removeUpload(jobId), 2500)
          }
        } catch {
          // Network hiccup — retry next cycle
        }
      }, POLL_INTERVAL_MS)

      pollRefs.current.set(jobId, handle)
    },
    [queryClient, updateUpload, removeUpload, stopPolling],
  )

  const pickAndUpload = useCallback(async (): Promise<{
    success: boolean
    error?: string
  }> => {
    let pickerResult: DocumentPicker.DocumentPickerResult
    try {
      pickerResult = await DocumentPicker.getDocumentAsync({
        type: ACCEPTED_TYPES,
        copyToCacheDirectory: true,
        multiple: false,
      })
    } catch {
      return { success: false, error: 'Could not open document picker.' }
    }

    if (pickerResult.canceled) return { success: false }

    const asset = pickerResult.assets[0]
    if (!asset) return { success: false }

    const filename = asset.name
    const mimeType = asset.mimeType ?? 'application/octet-stream'

    const formData = new FormData()
    formData.append('file', {
      uri: asset.uri,
      name: filename,
      type: mimeType,
    } as unknown as Blob)

    try {
      const response = await api.post('/files/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
        timeout: 120_000,
      })

      const { bookId, jobId } = response.data.data as {
        bookId: string
        jobId: string
      }

      addUpload({
        bookId,
        jobId,
        filename,
        status: 'queued',
        progress: 0,
      })

      startPolling(jobId)
      return { success: true }
    } catch (error: unknown) {
      if (typeof error === 'object' && error !== null && 'response' in error) {
        const e = error as {
          response?: { status?: number; data?: { message?: string } }
        }

        if (e.response?.status === 403) {
          return {
            success: false,
            error:
              e.response.data?.message ??
              'Free plan limit reached. Upgrade to Premium.',
          }
        }
        if (e.response?.status === 400) {
          return {
            success: false,
            error:
              e.response.data?.message ??
              'Invalid file. Make sure it is a text-based PDF or supported format.',
          }
        }
      }
      return {
        success: false,
        error: 'Upload failed. Please check your connection and try again.',
      }
    }
  }, [addUpload, startPolling])

  return { pickAndUpload }
}
