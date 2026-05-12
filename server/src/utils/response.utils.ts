import type { Response } from 'express'

// ── Response shapes ───────────────────────────────────────────────────────────

interface SuccessBody<T> {
  success: true
  message: string
  data: T
}

interface ErrorBody {
  success: false
  message: string
  errors?: unknown
}

// ── Helpers ───────────────────────────────────────────────────────────────────

export const successResponse = <T>(
  res: Response,
  data: T,
  message = 'Success',
  statusCode = 200,
): Response<SuccessBody<T>> => {
  return res.status(statusCode).json({
    success: true,
    message,
    data,
  } satisfies SuccessBody<T>)
}

export const errorResponse = (
  res: Response,
  message: string,
  statusCode = 500,
  errors?: unknown,
): Response<ErrorBody> => {
  const body: ErrorBody = { success: false, message }

  // Only attach errors key when a value was provided (exactOptionalPropertyTypes safe)
  if (errors !== undefined) {
    body.errors = errors
  }

  return res.status(statusCode).json(body)
}
