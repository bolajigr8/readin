import multer, { type FileFilterCallback } from 'multer'
import type { Request } from 'express'

const ALLOWED_MIME_TYPES = new Set([
  'application/pdf',
  'application/epub+zip',
  'application/x-mobipocket-ebook',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain',
])

const MAX_FILE_SIZE = 100 * 1024 * 1024 // 100 MB

const storage = multer.memoryStorage()

const fileFilter = (
  _req: Request,
  file: Express.Multer.File,
  cb: FileFilterCallback,
): void => {
  if (ALLOWED_MIME_TYPES.has(file.mimetype)) {
    cb(null, true)
  } else {
    cb(new Error('Unsupported file type. Allowed: PDF, EPUB, MOBI, DOCX, TXT'))
  }
}

const upload = multer({
  storage,
  limits: { fileSize: MAX_FILE_SIZE },
  fileFilter,
})

export const uploadSingle = upload.single('file')
