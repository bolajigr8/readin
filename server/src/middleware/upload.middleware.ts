import multer, { type FileFilterCallback } from 'multer'
import type { Request } from 'express'
import path from 'path'

// Phones frequently send "application/octet-stream" (or an empty type) for
// .epub/.pdf picked from the Files app. We accept those and let the controller
// decide the real format from the extension + magic bytes.
const ALLOWED_MIME_TYPES = new Set([
  'application/pdf',
  'application/epub+zip',
  'application/x-mobipocket-ebook',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain',
  'application/octet-stream',
  'application/zip',
  'binary/octet-stream',
  '',
])

const ALLOWED_EXTENSIONS = new Set(['.pdf', '.epub', '.mobi', '.docx', '.txt'])

const MAX_FILE_SIZE = 100 * 1024 * 1024 // 100 MB

const storage = multer.memoryStorage()

const fileFilter = (
  _req: Request,
  file: Express.Multer.File,
  cb: FileFilterCallback,
): void => {
  const ext = path.extname(file.originalname).toLowerCase()
  if (ALLOWED_MIME_TYPES.has(file.mimetype) && ALLOWED_EXTENSIONS.has(ext)) {
    cb(null, true)
  } else {
    cb(new Error('Unsupported file type. Allowed: PDF and EPUB'))
  }
}

const upload = multer({
  storage,
  limits: { fileSize: MAX_FILE_SIZE },
  fileFilter,
})

export const uploadSingle = upload.single('file')
