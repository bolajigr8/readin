import type { Request, Response, NextFunction } from 'express'

// ── Type helpers ──────────────────────────────────────────────────────────────

interface MongooseValidationError {
  name: 'ValidationError'
  errors: Record<string, { message: string }>
}

const isObject = (v: unknown): v is Record<string, unknown> =>
  typeof v === 'object' && v !== null

const hasName = (v: unknown, name: string): boolean =>
  isObject(v) && 'name' in v && v['name'] === name

const hasCode = (v: unknown, code: unknown): boolean =>
  isObject(v) && 'code' in v && v['code'] === code

// ── Global error handler ──────────────────────────────────────────────────────

export const globalErrorHandler = (
  err: unknown,
  req: Request,
  res: Response,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  _next: NextFunction,
): void => {
  // Always log server-side — never expose stack traces to clients
  console.error(`[${new Date().toISOString()}] ${req.method} ${req.path}`, err)

  // ── Mongoose validation error ─────────────────────────────────────────────
  if (hasName(err, 'ValidationError') && isObject(err) && 'errors' in err) {
    const validationErr = err as unknown as MongooseValidationError
    const fieldErrors = Object.fromEntries(
      Object.entries(validationErr.errors).map(([key, val]) => [
        key,
        val.message,
      ]),
    )
    res.status(400).json({
      success: false,
      message: 'Validation failed.',
      errors: fieldErrors,
    })
    return
  }

  // ── MongoDB duplicate key (code 11000) ────────────────────────────────────
  if (hasCode(err, 11000)) {
    res.status(409).json({
      success: false,
      message: 'Resource already exists.',
    })
    return
  }

  // ── JWT errors ────────────────────────────────────────────────────────────
  if (hasName(err, 'JsonWebTokenError')) {
    res.status(401).json({ success: false, message: 'Invalid token.' })
    return
  }

  if (hasName(err, 'TokenExpiredError')) {
    res.status(401).json({ success: false, message: 'Token expired.' })
    return
  }

  // ── Multer: file too large ────────────────────────────────────────────────
  if (hasCode(err, 'LIMIT_FILE_SIZE')) {
    res.status(400).json({
      success: false,
      message: 'File too large. Maximum size is 100MB.',
    })
    return
  }

  // ── Multer: unsupported file type (thrown as plain Error) ─────────────────
  if (isObject(err) && 'message' in err) {
    const message = String(err['message'])
    if (message.includes('Unsupported file type')) {
      res.status(400).json({ success: false, message })
      return
    }
  }

  // ── Default 500 ───────────────────────────────────────────────────────────
  res.status(500).json({
    success: false,
    message: 'Something went wrong. Please try again.',
  })
}

// ── 404 handler ───────────────────────────────────────────────────────────────

export const notFoundHandler = (req: Request, res: Response): void => {
  res.status(404).json({
    success: false,
    message: `Route ${req.method} ${req.path} not found.`,
  })
}
