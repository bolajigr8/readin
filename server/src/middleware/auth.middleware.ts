import type { Request, Response, NextFunction } from 'express'
import { verifyAccessToken } from '../utils/jwt.utils.js'
import { errorResponse } from '../utils/response.utils.js'

/**
 * protect — verifies the Bearer access token and attaches `req.user`.
 * Must be applied before any handler that needs authentication.
 */
export const protect = (
  req: Request,
  res: Response,
  next: NextFunction,
): void => {
  const authHeader = req.headers.authorization

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    errorResponse(
      res,
      "No token provided. Use 'Authorization: Bearer <token>'.",
      401,
    )
    return
  }

  const token = authHeader.slice(7) // strip "Bearer "

  try {
    const decoded = verifyAccessToken(token)
    req.user = { userId: decoded.userId, plan: decoded.plan }
    next()
  } catch {
    errorResponse(res, 'Invalid or expired access token.', 401)
  }
}

/**
 * requirePremium — must be used AFTER `protect`.
 * Rejects non-premium users with 403.
 */
export const requirePremium = (
  req: Request,
  res: Response,
  next: NextFunction,
): void => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }

  if (req.user.plan !== 'premium') {
    errorResponse(res, 'This feature requires a Premium subscription.', 403)
    return
  }

  next()
}
