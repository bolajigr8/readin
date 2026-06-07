// ── Book ──────────────────────────────────────────────────────────────────────

export interface BookProgress {
  percentage: number
  lastReadAt: string
  isCompleted: boolean
}

export interface Book {
  _id: string
  userId: string
  title: string
  author: string
  description: string
  coverUrl: string
  originalFileUrl: string
  originalFilePublicId: string
  convertedFileUrl: string
  convertedFilePublicId: string
  originalFormat: 'pdf' | 'epub' | 'mobi' | 'docx' | 'txt'
  fileSize: number
  pageCount: number
  status: 'uploading' | 'queued' | 'converting' | 'ready' | 'failed'
  jobId: string
  isDownloaded: boolean
  source: 'upload' | 'discover'
  gutenbergId: string | null
  language: string
  genre: string
  createdAt: string
  updatedAt: string
  // Joined from Progress collection by GET /library
  progress?: BookProgress | null
}

// ── Library API response ──────────────────────────────────────────────────────

export interface LibraryMeta {
  total: number
  page: number
  limit: number
  totalPages: number
  limitReached: boolean
}

export interface LibraryResponse {
  books: Book[]
  meta: LibraryMeta
}

// ── Upload tracking (client-side only) ───────────────────────────────────────

export interface ActiveUpload {
  bookId: string
  jobId: string
  filename: string
  status: 'uploading' | 'queued' | 'converting' | 'ready' | 'failed'
  progress: number
  error?: string
}

// ── Job status from API ───────────────────────────────────────────────────────

export interface JobStatus {
  jobId: string
  bookId: string
  status: 'waiting' | 'active' | 'completed' | 'failed'
  progress: number
  startedAt: string | null
  completedAt: string | null
  error?: string
}
