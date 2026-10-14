import type { NextFunction, Request, Response } from 'express'
import { User } from '../models/user.model.js'
import { errorResponse } from '../utils/response.utils.js'

/**
 * requireAdmin — use AFTER `protect`.
 *  1. the role is read from the DATABASE (not from the token),
 *  2. the account must not be disabled,
 *  3. if ADMIN_EMAILS is set (comma-separated) the e-mail must be on that list —
 *     a second lock: even a wrongly-set role cannot open the admin API.
 * Failures answer a plain 403 so nothing about the admin API leaks.
 */
export const requireAdmin = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    if (!req.user) {
      errorResponse(res, 'Not authenticated.', 401)
      return
    }
    const u = await User.findById(req.user.userId).select('role email disabled').lean()
    const allow = (process.env['ADMIN_EMAILS'] ?? '')
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .filter(Boolean)

    const ok =
      !!u &&
      u.role === 'admin' &&
      u.disabled !== true &&
      (allow.length === 0 || allow.includes(u.email.toLowerCase()))

    if (!ok) {
      errorResponse(res, 'Forbidden.', 403)
      return
    }
    next()
  } catch (err) {
    next(err)
  }
}
