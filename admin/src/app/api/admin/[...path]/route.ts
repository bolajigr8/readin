import { NextRequest, NextResponse } from 'next/server'
import {
  ACCESS_COOKIE,
  ACCESS_MAX_AGE,
  REFRESH_COOKIE,
  cookieOptions,
  isTrustedRequest,
  messageFrom,
  targetPath,
} from '@/lib/proxy-utils'
import { callApi } from '@/lib/server/upstream'

const json = (status: number, message: string) => NextResponse.json({ success: false, message }, { status })

/** Only these query parameters are forwarded (and only short values). */
const forwardQuery = (url: URL): string => {
  const q = new URLSearchParams()
  for (const key of ['search', 'page', 'limit', 'status']) {
    const v = url.searchParams.get(key)
    if (v !== null && v.length <= 80) q.set(key, v)
  }
  const s = q.toString()
  return s ? `?${s}` : ''
}

/**
 * Authenticated proxy to the ReadIn admin API (see lib/proxy-utils.ts):
 *  • exact path whitelist, GET/POST/PUT/PATCH only
 *  • writes need same origin + the x-requested-with header (CSRF)
 *  • the access token is renewed with the refresh cookie when it expires
 */
async function handler(req: NextRequest) {
  const url = new URL(req.url)
  const path = targetPath(url.pathname, req.method)
  if (!path) return json(404, 'Not found.')

  if (
    !isTrustedRequest(req.method, req.headers.get('origin'), req.headers.get('host'), req.headers.get('x-requested-with'))
  ) {
    return json(403, 'Request blocked.')
  }

  let payload: unknown
  if (req.method !== 'GET') {
    const text = await req.text()
    if (text.length > 20_000) return json(413, 'Request too large.')
    try {
      payload = text ? JSON.parse(text) : {}
    } catch {
      return json(400, 'Invalid JSON.')
    }
  }

  const at = req.cookies.get(ACCESS_COOKIE)?.value
  const rt = req.cookies.get(REFRESH_COOKIE)?.value
  if (!at && !rt) return json(401, 'Not signed in.')

  const prod = process.env.NODE_ENV === 'production'
  const target = `admin/${path}${req.method === 'GET' ? forwardQuery(url) : ''}`
  const forward = (token: string) => callApi(target, { method: req.method, token, json: payload })

  let up = at ? await forward(at) : { status: 401, body: null as unknown }
  let renewed: string | null = null

  if (up.status === 401 && rt) {
    const r = await callApi('auth/refresh', { method: 'POST', json: { refreshToken: rt } })
    const token = (r.body as { data?: { accessToken?: unknown } } | null)?.data?.accessToken
    if (r.status === 200 && typeof token === 'string') {
      renewed = token
      up = await forward(token)
    }
  }

  const clear = (res: NextResponse) => {
    res.cookies.set(ACCESS_COOKIE, '', cookieOptions(0, prod))
    res.cookies.set(REFRESH_COOKIE, '', cookieOptions(0, prod))
    return res
  }

  if (up.status === 401) return clear(json(401, 'Your session has expired. Please sign in again.'))

  const body =
    up.body === null || typeof up.body !== 'object'
      ? { success: false, message: messageFrom(up.body, 'Unexpected response from the API.') }
      : up.body
  const res = NextResponse.json(body, { status: up.status === 200 && up.body === null ? 502 : up.status })
  if (renewed) res.cookies.set(ACCESS_COOKIE, renewed, cookieOptions(ACCESS_MAX_AGE, prod))
  return res
}

export { handler as GET, handler as POST, handler as PUT, handler as PATCH }
