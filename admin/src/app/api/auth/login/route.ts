import { NextRequest, NextResponse } from 'next/server'
import {
  ACCESS_COOKIE,
  ACCESS_MAX_AGE,
  REFRESH_COOKIE,
  REFRESH_MAX_AGE,
  cookieOptions,
  isTrustedRequest,
  messageFrom,
} from '@/lib/proxy-utils'
import { callApi } from '@/lib/server/upstream'

interface LoginData {
  accessToken?: unknown
  refreshToken?: unknown
  user?: { email?: unknown; displayName?: unknown; role?: unknown }
}

const fail = (status: number, message: string) => NextResponse.json({ message }, { status })

/**
 * POST /api/auth/login — signs in through the ReadIn API and keeps the tokens in
 * httpOnly cookies (JavaScript in the browser can never read them).
 * Only accounts with role "admin" get a session.
 */
export async function POST(req: NextRequest) {
  if (
    !isTrustedRequest('POST', req.headers.get('origin'), req.headers.get('host'), req.headers.get('x-requested-with'))
  ) {
    return fail(403, 'Request blocked.')
  }

  let input: { email?: unknown; password?: unknown } = {}
  try {
    input = (await req.json()) as typeof input
  } catch {
    return fail(400, 'Invalid request.')
  }
  const email = typeof input.email === 'string' ? input.email.trim().toLowerCase() : ''
  const password = typeof input.password === 'string' ? input.password : ''
  if (!email || email.length > 200 || !password || password.length > 200) {
    return fail(400, 'Enter your e-mail and password.')
  }

  const up = await callApi('auth/login', { method: 'POST', json: { email, password } })
  if (up.status !== 200) {
    const known = [400, 401, 403, 429, 500, 504].includes(up.status) ? up.status : 502
    return fail(known, messageFrom(up.body, 'Sign-in failed.'))
  }

  const data = (up.body as { data?: LoginData } | null)?.data
  const at = data?.accessToken
  const rt = data?.refreshToken
  if (typeof at !== 'string' || typeof rt !== 'string') {
    return fail(502, 'Unexpected response from the API.')
  }

  // Only administrators may use this panel. Anyone else: undo the session we just opened.
  if (data?.user?.role !== 'admin') {
    await callApi('auth/logout', { method: 'POST', json: { refreshToken: rt } })
    return fail(403, 'This account is not an administrator.')
  }

  const prod = process.env.NODE_ENV === 'production'
  const res = NextResponse.json({
    user: {
      email: typeof data.user?.email === 'string' ? data.user.email : email,
      displayName: typeof data.user?.displayName === 'string' ? data.user.displayName : 'Administrator',
    },
  })
  res.cookies.set(ACCESS_COOKIE, at, cookieOptions(ACCESS_MAX_AGE, prod))
  res.cookies.set(REFRESH_COOKIE, rt, cookieOptions(REFRESH_MAX_AGE, prod))
  return res
}
