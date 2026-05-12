import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { z } from 'zod'
import bcrypt from 'bcryptjs'
import { v4 as uuidv4 } from 'uuid'

import { User } from '../models/user.model.js'
import {
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
} from '../utils/jwt.utils.js'
import { successResponse, errorResponse } from '../utils/response.utils.js'
import { emailService } from '../services/email/email.service.js'

// ── Zod Schemas ───────────────────────────────────────────────────────────────

const registerSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  displayName: z
    .string()
    .min(1, 'Display name is required')
    .max(50, 'Display name must be 50 characters or less')
    .trim(),
})

const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(1, 'Password is required'),
})

const googleOAuthSchema = z.object({
  googleId: z.string().min(1, 'googleId is required'),
  email: z.string().email('Invalid email address'),
  displayName: z.string().min(1, 'displayName is required'),
  avatar: z.string().url().optional().default(''),
})

const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'refreshToken is required'),
})

const forgotPasswordSchema = z.object({
  email: z.string().email('Invalid email address'),
})

const resetPasswordSchema = z.object({
  token: z.string().min(1, 'Reset token is required'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
})

// ── Shared user shape returned to clients ─────────────────────────────────────

const formatUser = (user: {
  _id: { toString(): string }
  email: string
  displayName: string
  avatar: string
  plan: string
  isEmailVerified: boolean
}) => ({
  id: user._id.toString(),
  email: user.email,
  displayName: user.displayName,
  avatar: user.avatar,
  plan: user.plan,
  isEmailVerified: user.isEmailVerified,
})

// ── Controllers ───────────────────────────────────────────────────────────────

/**
 * POST /api/v1/auth/register
 */
export const register = asyncHandler(async (req: Request, res: Response) => {
  const parsed = registerSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(
      res,
      'Validation failed',
      400,
      parsed.error.flatten().fieldErrors,
    )
    return
  }

  const { email, password, displayName } = parsed.data
  const normalizedEmail = email.toLowerCase()

  const existing = await User.findOne({ email: normalizedEmail })
  if (existing) {
    errorResponse(res, 'An account with that email already exists.', 409)
    return
  }

  const passwordHash = await bcrypt.hash(password, 12)
  const emailVerificationToken = uuidv4()
  const emailVerificationExpires = new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 h

  const user = await User.create({
    email: normalizedEmail,
    passwordHash,
    displayName,
    emailVerificationToken,
    emailVerificationExpires,
  })

  const accessToken = generateAccessToken(user._id.toString(), user.plan)
  const refreshToken = generateRefreshToken(user._id.toString())

  user.refreshTokens.push(refreshToken)
  await user.save()

  // Fire-and-forget — don't block the response
  emailService
    .sendVerificationEmail(user.email, user.displayName, emailVerificationToken)
    .catch((err: unknown) =>
      console.error('[email] Failed to send verification email:', err),
    )

  successResponse(
    res,
    {
      accessToken,
      refreshToken,
      user: formatUser(user),
    },
    'Registration successful. Please check your email to verify your account.',
    201,
  )
})

/**
 * POST /api/v1/auth/login
 */
export const login = asyncHandler(async (req: Request, res: Response) => {
  const parsed = loginSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(
      res,
      'Validation failed',
      400,
      parsed.error.flatten().fieldErrors,
    )
    return
  }

  const { email, password } = parsed.data

  const user = await User.findOne({ email: email.toLowerCase() })

  // Intentionally vague message to avoid user enumeration
  if (!user || !user.passwordHash) {
    errorResponse(res, 'Invalid email or password.', 401)
    return
  }

  const passwordMatch = await bcrypt.compare(password, user.passwordHash)
  if (!passwordMatch) {
    errorResponse(res, 'Invalid email or password.', 401)
    return
  }

  if (!user.isEmailVerified) {
    errorResponse(
      res,
      'Please verify your email before logging in. Check your inbox for the verification link.',
      403,
    )
    return
  }

  const accessToken = generateAccessToken(user._id.toString(), user.plan)
  const refreshToken = generateRefreshToken(user._id.toString())

  user.refreshTokens.push(refreshToken)
  await user.save()

  successResponse(
    res,
    {
      accessToken,
      refreshToken,
      user: formatUser(user),
    },
    'Login successful.',
  )
})

/**
 * POST /api/v1/auth/google
 * The mobile app handles the OAuth consent flow via expo-auth-session
 * and forwards the resolved user info here for upsert + token generation.
 */
export const googleOAuth = asyncHandler(async (req: Request, res: Response) => {
  const parsed = googleOAuthSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(
      res,
      'Validation failed',
      400,
      parsed.error.flatten().fieldErrors,
    )
    return
  }

  const { googleId, email, displayName, avatar } = parsed.data
  const normalizedEmail = email.toLowerCase()

  // ── Resolve the user (find / link / create) ────────────────────────────────
  const resolvedUser = await (async () => {
    // 1. Already has a Google account
    const byGoogleId = await User.findOne({ googleId })
    if (byGoogleId) return byGoogleId

    // 2. Has an email account — link Google to it
    const byEmail = await User.findOne({ email: normalizedEmail })
    if (byEmail) {
      byEmail.googleId = googleId
      byEmail.isEmailVerified = true
      if (avatar) byEmail.avatar = avatar
      await byEmail.save()
      return byEmail
    }

    // 3. Brand-new user
    return User.create({
      email: normalizedEmail,
      googleId,
      displayName,
      avatar,
      isEmailVerified: true,
      passwordHash: null,
    })
  })()
  // TypeScript now knows resolvedUser is IUser (never null) ✓

  const accessToken = generateAccessToken(
    resolvedUser._id.toString(),
    resolvedUser.plan,
  )
  const refreshToken = generateRefreshToken(resolvedUser._id.toString())

  resolvedUser.refreshTokens.push(refreshToken)
  await resolvedUser.save()

  successResponse(
    res,
    {
      accessToken,
      refreshToken,
      user: formatUser(resolvedUser),
    },
    'Google authentication successful.',
  )
})

/**
 * POST /api/v1/auth/refresh
 */
export const refreshToken = asyncHandler(
  async (req: Request, res: Response) => {
    const parsed = refreshTokenSchema.safeParse(req.body)
    if (!parsed.success) {
      errorResponse(res, 'refreshToken field is required.', 400)
      return
    }

    const { refreshToken: token } = parsed.data

    let payload
    try {
      payload = verifyRefreshToken(token)
    } catch {
      errorResponse(res, 'Invalid or expired refresh token.', 401)
      return
    }

    // Security: verify the token is still stored for this user (not revoked)
    const user = await User.findOne({
      _id: payload.userId,
      refreshTokens: token,
    })

    if (!user) {
      errorResponse(
        res,
        'Refresh token not recognised. Please log in again.',
        401,
      )
      return
    }

    const accessToken = generateAccessToken(user._id.toString(), user.plan)

    successResponse(res, { accessToken }, 'Access token refreshed.')
  },
)

/**
 * POST /api/v1/auth/logout
 */
export const logout = asyncHandler(async (req: Request, res: Response) => {
  const parsed = refreshTokenSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'refreshToken field is required.', 400)
    return
  }

  const { refreshToken: token } = parsed.data

  // Remove only this device's token; other sessions stay alive
  await User.updateOne(
    { refreshTokens: token },
    { $pull: { refreshTokens: token } },
  )

  successResponse(res, null, 'Logged out successfully.')
})

/**
 * GET /api/v1/auth/verify-email/:token
 */
export const verifyEmail = asyncHandler(async (req: Request, res: Response) => {
  const token = req.params['token']

  if (!token) {
    errorResponse(res, 'Verification token is missing.', 400)
    return
  }

  const user = await User.findOne({
    emailVerificationToken: token,
    emailVerificationExpires: { $gt: new Date() },
  })

  if (!user) {
    errorResponse(
      res,
      'Verification link is invalid or has expired. Please request a new one.',
      400,
    )
    return
  }

  user.isEmailVerified = true
  user.emailVerificationToken = null
  user.emailVerificationExpires = null
  await user.save()

  // Fire-and-forget welcome email
  emailService
    .sendWelcomeEmail(user.email, user.displayName)
    .catch((err: unknown) =>
      console.error('[email] Failed to send welcome email:', err),
    )

  successResponse(res, null, 'Email verified successfully. You can now log in.')
})

/**
 * POST /api/v1/auth/forgot-password
 */
export const forgotPassword = asyncHandler(
  async (req: Request, res: Response) => {
    const parsed = forgotPasswordSchema.safeParse(req.body)
    if (!parsed.success) {
      errorResponse(res, 'A valid email address is required.', 400)
      return
    }

    const { email } = parsed.data

    // Always return the same message — never reveal whether the email exists
    const safeMessage =
      'If an account with that email exists, a password reset link has been sent.'

    const user = await User.findOne({ email: email.toLowerCase() })
    if (!user) {
      // Intentionally same response
      successResponse(res, null, safeMessage)
      return
    }

    const resetToken = uuidv4()
    user.passwordResetToken = resetToken
    user.passwordResetExpires = new Date(Date.now() + 60 * 60 * 1000) // 1 h
    await user.save()

    emailService
      .sendPasswordResetEmail(user.email, user.displayName, resetToken)
      .catch((err: unknown) =>
        console.error('[email] Failed to send password reset email:', err),
      )

    successResponse(res, null, safeMessage)
  },
)

/**
 * POST /api/v1/auth/reset-password
 */
export const resetPassword = asyncHandler(
  async (req: Request, res: Response) => {
    const parsed = resetPasswordSchema.safeParse(req.body)
    if (!parsed.success) {
      errorResponse(
        res,
        'Validation failed',
        400,
        parsed.error.flatten().fieldErrors,
      )
      return
    }

    const { token, password } = parsed.data

    const user = await User.findOne({
      passwordResetToken: token,
      passwordResetExpires: { $gt: new Date() },
    })

    if (!user) {
      errorResponse(res, 'Password reset link is invalid or has expired.', 400)
      return
    }

    user.passwordHash = await bcrypt.hash(password, 12)
    user.passwordResetToken = null
    user.passwordResetExpires = null
    user.refreshTokens = [] // Revoke all sessions — force re-login everywhere
    await user.save()

    successResponse(
      res,
      null,
      'Password reset successfully. Please log in with your new password.',
    )
  },
)
