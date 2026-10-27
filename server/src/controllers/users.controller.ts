import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { z } from 'zod'
import { User } from '../models/user.model.js'
import { successResponse, errorResponse } from '../utils/response.utils.js'

const pushTokenSchema = z.object({
  expoPushToken: z
    .string()
    .startsWith('ExponentPushToken[', 'Invalid Expo push token format'),
})

/**
 * PUT /api/v1/users/push-token
 * Saves the device's Expo push token to the authenticated user's document.
 */
export const savePushToken = asyncHandler(
  async (req: Request, res: Response) => {
    const parsed = pushTokenSchema.safeParse(req.body)
    if (!parsed.success) {
      errorResponse(
        res,
        'Validation failed',
        400,
        parsed.error.flatten().fieldErrors,
      )
      return
    }

    if (!req.user) {
      errorResponse(res, 'Not authenticated.', 401)
      return
    }

    const { expoPushToken } = parsed.data

    await User.findByIdAndUpdate(req.user.userId, { expoPushToken })

    successResponse(res, null, 'Push token saved successfully.')
  },
)

/**
 * GET /api/v1/users/me — the signed-in user, always fresh from the database
 * (plan with expiry applied, premium end date, verification state).
 */
export const getMe = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }
  const u = await User.findById(req.user.userId)
  if (!u) {
    errorResponse(res, 'Account not found.', 404)
    return
  }
  successResponse(res, {
    user: {
      id: u._id.toString(),
      email: u.email,
      displayName: u.displayName,
      avatar: u.avatar,
      plan: req.user.plan,
      role: u.role,
      premiumUntil: u.premiumUntil ?? null,
      isEmailVerified: u.isEmailVerified,
    },
  })
})
