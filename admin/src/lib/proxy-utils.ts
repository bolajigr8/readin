/**
 * Pure helpers for the admin "backend-for-frontend" (BFF). No Next.js imports so
 * they can be unit-tested with plain Node (tests/proxy-utils.test.mjs).
 *
 * The browser NEVER talks to the ReadIn API directly and never sees a token:
 *   browser ⇄ /api/admin/*  (this Next.js app, same origin, httpOnly cookies)
 *           ⇄ ReadIn API    (server-to-server, Bearer token)
 */

export const ACCESS_COOKIE = 'readin_admin_at'
export const REFRESH_COOKIE = 'readin_admin_rt'

/** Access tokens live 15 min on the API; expire the cookie a minute earlier. */
export const ACCESS_MAX_AGE = 14 * 60
/** Refresh tokens live 7 days on the API. */
export const REFRESH_MAX_AGE = 7 * 24 * 60 * 60

export const PROXY_PREFIX = '/api/admin/'

/** Only these admin API paths can be reached through the proxy (no SSRF, no surprises). */
const ALLOWED: RegExp[] = [
  /^stats$/,
  /^audit$/,
  /^config$/,
  /^config\/features\/[a-z_]{1,40}$/,
  /^billing$/,
  /^payments$/,
  /^users$/,
  /^users\/[a-f0-9]{24}$/,
  /^users\/[a-f0-9]{24}\/verify$/,
  /^users\/[a-f0-9]{24}\/features\/[a-z_]{1,40}\/(grant|revoke|restore|reset-trial)$/,
]

const METHODS = new Set(['GET', 'POST', 'PUT', 'PATCH'])

/**
 * "/api/admin/users/abc" → "users/abc". Returns null for anything that is not an
 * exact, allowed admin API path (traversal, encoded slashes, unknown routes…).
 */
export const targetPath = (pathname: string, method: string): string | null => {
  if (!METHODS.has(method.toUpperCase())) return null
  if (!pathname.startsWith(PROXY_PREFIX)) return null
  const rest = pathname.slice(PROXY_PREFIX.length).replace(/\/+$/, '')
  if (!rest || rest.includes('..') || rest.includes('//') || rest.includes('%') || rest.includes('\\')) {
    return null
  }
  return ALLOWED.some((r) => r.test(rest)) ? rest : null
}

/** Reads must come from this site; writes must also carry our custom header. */
export const isSameOrigin = (origin: string | null, host: string | null): boolean => {
  if (!origin || !host) return false
  try {
    return new URL(origin).host === host
  } catch {
    return false
  }
}

export const isTrustedRequest = (
  method: string,
  origin: string | null,
  host: string | null,
  requestedWith: string | null,
): boolean => {
  if (method.toUpperCase() === 'GET') return true // GET never changes anything
  return isSameOrigin(origin, host) && requestedWith === 'admin'
}

export interface CookieOptions {
  httpOnly: true
  secure: boolean
  sameSite: 'strict'
  path: '/'
  maxAge: number
}

export const cookieOptions = (maxAge: number, production: boolean): CookieOptions => ({
  httpOnly: true,
  secure: production,
  sameSite: 'strict',
  path: '/',
  maxAge,
})

/** API base URL from the server-side env var, without a trailing slash. */
export const apiBase = (raw: string | undefined): string | null => {
  const v = (raw ?? '').trim().replace(/\/+$/, '')
  if (!/^https?:\/\/[^\s]+$/.test(v)) return null
  return v
}

/** Safe, short message from an API error body (never leaks HTML error pages). */
export const messageFrom = (body: unknown, fallback: string): string => {
  if (body && typeof body === 'object' && 'message' in body) {
    const m = (body as { message?: unknown }).message
    if (typeof m === 'string' && m.length > 0 && m.length < 300) return m
  }
  return fallback
}
