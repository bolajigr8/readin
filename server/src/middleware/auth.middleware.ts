import type { Request, Response, NextFunction } from 'express'
import { verifyAccessToken } from '../utils/jwt.utils.js'
import { errorResponse } from '../utils/response.utils.js'
import { User } from '../models/user.model.js'
import { effectivePlan } from '../services/billing.logic.js'

/**
 * protect — verifies the Bearer access token and attaches `req.user`.
 * The plan and the "disabled" flag are read from the DATABASE on every request
 * (not trusted from the 15-minute token), so a payment, an expiry or an admin
 * action takes effect immediately.
 */
export const protect = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
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

  let userId: string
  try {
    userId = verifyAccessToken(token).userId
  } catch {
    errorResponse(res, 'Invalid or expired access token.', 401)
    return
  }

  try {
    const u = await User.findById(userId).select('plan premiumUntil disabled').lean()
    if (!u || u.disabled === true) {
      errorResponse(res, 'Invalid or expired access token.', 401)
      return
    }
    const stored = u.plan === 'premium' ? 'premium' : 'free'
    const plan = effectivePlan(stored, u.premiumUntil ?? null, new Date())
    if (stored === 'premium' && plan === 'free') {
      // paid period is over → store it (best effort)
      User.updateOne({ _id: u._id, plan: 'premium' }, { $set: { plan: 'free' } }).catch(() => undefined)
    }
    req.user = { userId, plan }
    next()
  } catch (err) {
    next(err)
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
