import { create } from 'zustand'
import type { ActiveUpload } from '@/types'

interface LibraryState {
  activeUploads: ActiveUpload[]
}

interface LibraryActions {
  addUpload: (upload: ActiveUpload) => void
  updateUpload: (jobId: string, partial: Partial<ActiveUpload>) => void
  removeUpload: (jobId: string) => void
}

export const useLibraryStore = create<LibraryState & LibraryActions>((set) => ({
  activeUploads: [],

  addUpload: (upload) =>
    set((state) => ({
      activeUploads: [...state.activeUploads, upload],
    })),

  updateUpload: (jobId, partial) =>
    set((state) => ({
      activeUploads: state.activeUploads.map((u) =>
        u.jobId === jobId ? { ...u, ...partial } : u,
      ),
    })),

  removeUpload: (jobId) =>
    set((state) => ({
      activeUploads: state.activeUploads.filter((u) => u.jobId !== jobId),
    })),
}))
