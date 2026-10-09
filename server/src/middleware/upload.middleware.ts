import multer, { type FileFilterCallback } from 'multer'
import type { Request } from 'express'
import path from 'path'

// Phones frequently send "application/octet-stream" (or an empty type) for
// .epub/.pdf picked from the Files app. We accept those and let the controller
// decide the real format from the extension + magic bytes.
// The file EXTENSION decides (phones send application/octet-stream or an empty
// type for most files). Every format the app can open is accepted.
const ALLOWED_EXTENSIONS = new Set([
  '.pdf', '.epub', '.mobi', '.azw3', '.fb2', '.cbz', '.cbr',
  '.docx', '.doc', '.odt', '.rtf',
  '.xlsx', '.xls', '.csv',
  '.pptx', '.ppt',
  '.txt', '.md', '.html', '.htm',
])

const MAX_FILE_SIZE = 100 * 1024 * 1024 // 100 MB

const storage = multer.memoryStorage()

const fileFilter = (
  _req: Request,
  file: Express.Multer.File,
  cb: FileFilterCallback,
): void => {
  const ext = path.extname(file.originalname).toLowerCase()
  if (ALLOWED_EXTENSIONS.has(ext)) {
    cb(null, true)
  } else {
    cb(new Error('Unsupported file type.'))
  }
}

const upload = multer({
  storage,
  limits: { fileSize: MAX_FILE_SIZE },
  fileFilter,
})

export const uploadSingle = upload.single('file')
