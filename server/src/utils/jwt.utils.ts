import jwt from 'jsonwebtoken'

export interface JwtPayload {
  userId: string
  plan: string
  iat?: number
  exp?: number
}

export interface RefreshPayload {
  userId: string
  iat?: number
  exp?: number
}

// ── Secret helpers (fail fast if env is missing) ──────────────────────────────

const getAccessSecret = (): string => {
  const secret = process.env['JWT_SECRET']
  if (!secret) throw new Error('JWT_SECRET is not configured')
  return secret
}

const getRefreshSecret = (): string => {
  const secret = process.env['JWT_REFRESH_SECRET']
  if (!secret) throw new Error('JWT_REFRESH_SECRET is not configured')
  return secret
}

// ── Token generators ──────────────────────────────────────────────────────────

/**
 * Access token — short lived (15 min).
 * Carries userId + plan so middleware never hits the DB.
 */
export const generateAccessToken = (userId: string, plan: string): string => {
  return jwt.sign({ userId, plan }, getAccessSecret(), { expiresIn: '15m' })
}

/**
 * Refresh token — long lived (7 days).
 * Only carries userId; plan is re-read on access-token generation.
 */
export const generateRefreshToken = (userId: string): string => {
  return jwt.sign({ userId }, getRefreshSecret(), { expiresIn: '7d' })
}

// ── Token verifiers ───────────────────────────────────────────────────────────

export const verifyAccessToken = (token: string): JwtPayload => {
  return jwt.verify(token, getAccessSecret()) as JwtPayload
}

export const verifyRefreshToken = (token: string): RefreshPayload => {
  return jwt.verify(token, getRefreshSecret()) as RefreshPayload
}
