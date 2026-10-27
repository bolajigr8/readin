import { NextRequest, NextResponse } from 'next/server'
import { ACCESS_COOKIE, REFRESH_COOKIE, cookieOptions, isTrustedRequest } from '@/lib/proxy-utils'
import { callApi } from '@/lib/server/upstream'

/** POST /api/auth/logout — revokes the refresh token on the API and clears the cookies. */
export async function POST(req: NextRequest) {
  if (
    !isTrustedRequest('POST', req.headers.get('origin'), req.headers.get('host'), req.headers.get('x-requested-with'))
  ) {
    return NextResponse.json({ message: 'Request blocked.' }, { status: 403 })
  }
  const rt = req.cookies.get(REFRESH_COOKIE)?.value
  if (rt) await callApi('auth/logout', { method: 'POST', json: { refreshToken: rt } })

  const prod = process.env.NODE_ENV === 'production'
  const res = NextResponse.json({ ok: true })
  res.cookies.set(ACCESS_COOKIE, '', cookieOptions(0, prod))
  res.cookies.set(REFRESH_COOKIE, '', cookieOptions(0, prod))
  return res
}
