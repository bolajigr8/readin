import { verifyGoogleIdToken } from '../utils/google.utils.js'
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
import { effectivePlan } from '../services/billing.logic.js'
import { verifyEmailPage } from '../services/pages/pages.js'

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
  role: string
  premiumUntil?: Date | null
  isEmailVerified: boolean
}) => ({
  id: user._id.toString(),
  email: user.email,
  displayName: user.displayName,
  avatar: user.avatar,
  plan: effectivePlan(user.plan === 'premium' ? 'premium' : 'free', user.premiumUntil ?? null, new Date()),
  role: user.role,
  premiumUntil: user.premiumUntil ?? null,
  isEmailVerified: user.isEmailVerified,
})

/** Paid time over → Free (so the token we hand out says so). Returns true when changed. */
const expirePlanIfNeeded = (user: { plan: 'free' | 'premium'; premiumUntil: Date | null }): boolean => {
  if (user.plan === 'premium' && effectivePlan('premium', user.premiumUntil, new Date()) === 'free') {
    user.plan = 'free'
    return true
  }
  return false
}

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

  if (user.disabled) {
    errorResponse(res, 'This account has been disabled. Please contact support.', 403)
    return
  }
  user.lastLoginAt = new Date()
  expirePlanIfNeeded(user)

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

  // SECURITY: the identity comes from a Google ID token verified with Google,
  // never from fields the client sends (otherwise anyone could sign in as any
  // e-mail address, including an administrator).
  const rawIdToken: unknown = (req.body as Record<string, unknown> | undefined)?.['idToken']
  const identity =
    typeof rawIdToken === 'string' && rawIdToken.length > 20
      ? await verifyGoogleIdToken(rawIdToken)
      : null
  if (!identity) {
    errorResponse(res, 'Google sign-in could not be verified.', 401)
    return
  }
  const googleId = identity.sub
  const normalizedEmail = identity.email.toLowerCase()
  const displayName = identity.name || parsed.data.displayName
  const avatar = identity.picture || parsed.data.avatar

  // ── Resolve the user (find / link / create) ────────────────────────────────
  const resolvedUser = await (async () => {
    // 1. Already has a Google account
    const byGoogleId = await User.findOne({ googleId })
    if (byGoogleId) return byGoogleId

    // 2. Has an email account — link Google to it
    const byEmail = await User.findOne({ email: normalizedEmail })
    if (byEmail && byEmail.role === 'admin') return byEmail // rejected below, never linked
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

  // Administrators sign in with e-mail + password only.
  if (resolvedUser.role === 'admin') {
    errorResponse(res, 'Administrator accounts must sign in with e-mail and password.', 403)
    return
  }
  if (resolvedUser.disabled) {
    errorResponse(res, 'This account has been disabled. Please contact support.', 403)
    return
  }
  resolvedUser.lastLoginAt = new Date()

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

    if (user.disabled) {
      errorResponse(res, 'This account has been disabled.', 401)
      return
    }

    if (expirePlanIfNeeded(user)) await user.save()
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

export type VerifyOutcome = 'ok' | 'already' | 'expired' | 'invalid'

/**
 * Confirms an e-mail address from the token in the e-mail. The token is kept
 * after use (until it expires) so that a second click — or a mail scanner that
 * opened the link first — still shows "confirmed" instead of an error.
 */
export const verifyEmailByToken = async (token: string): Promise<VerifyOutcome> => {
  if (!token || token.length > 100) return 'invalid'
  const user = await User.findOne({ emailVerificationToken: token })
  if (!user) return 'invalid'
  if (user.isEmailVerified) return 'already'
  if (!user.emailVerificationExpires || user.emailVerificationExpires.getTime() < Date.now()) {
    return 'expired'
  }

  user.isEmailVerified = true
  await user.save()

  // Fire-and-forget welcome email
  emailService
    .sendWelcomeEmail(user.email, user.displayName)
    .catch((err: unknown) => console.error('[email] Failed to send welcome email:', err))
  return 'ok'
}

/** Is this password-reset token real and not expired? (used by the reset page) */
export const isResetTokenValid = async (token: string): Promise<boolean> => {
  if (!token || token.length > 100) return false
  const user = await User.findOne({
    passwordResetToken: token,
    passwordResetExpires: { $gt: new Date() },
  }).select('_id')
  return !!user
}

/**
 * GET /api/v1/auth/verify-email/:token
 * (Old e-mails still point here.) Browsers get the pretty page, apps get JSON.
 */
export const verifyEmail = asyncHandler(async (req: Request, res: Response) => {
  const token = String(req.params['token'] ?? '')
  const outcome = await verifyEmailByToken(token)

  if (req.accepts(['json', 'html']) === 'html') {
    res.status(outcome === 'ok' || outcome === 'already' ? 200 : 400).type('html').send(verifyEmailPage(outcome))
    return
  }
  if (outcome === 'ok' || outcome === 'already') {
    successResponse(res, null, 'Email verified successfully. You can now log in.')
    return
  }
  errorResponse(res, 'Verification link is invalid or has expired. Please request a new one.', 400)
})

/**
 * POST /api/v1/auth/resend-verification  { email }
 * Always answers the same (never reveals whether an account exists).
 */
export const resendVerification = asyncHandler(async (req: Request, res: Response) => {
  const parsed = forgotPasswordSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'A valid email address is required.', 400)
    return
  }
  const safe = 'If that account still needs confirming, a new link is on its way.'
  const user = await User.findOne({ email: parsed.data.email.toLowerCase() })
  if (!user || user.isEmailVerified) {
    successResponse(res, null, safe)
    return
  }
  // At most one new e-mail per minute per account.
  const issuedAt = user.emailVerificationExpires ? user.emailVerificationExpires.getTime() - 24 * 3600_000 : 0
  if (Date.now() - issuedAt < 60_000) {
    successResponse(res, null, safe)
    return
  }
  const token = uuidv4()
  user.emailVerificationToken = token
  user.emailVerificationExpires = new Date(Date.now() + 24 * 3600_000)
  await user.save()
  emailService
    .sendVerificationEmail(user.email, user.displayName, token)
    .catch((err: unknown) => console.error('[email] Failed to resend verification:', err))
  successResponse(res, null, safe)
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

    emailService
      .sendPasswordChangedEmail(user.email, user.displayName)
      .catch((err: unknown) => console.error('[email] Failed to send password-changed notice:', err))

    successResponse(
      res,
      null,
      'Password reset successfully. Please log in with your new password.',
    )
  },
)
