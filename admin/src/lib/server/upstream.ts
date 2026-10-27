import { apiBase } from '@/lib/proxy-utils'

export interface Upstream {
  status: number
  body: unknown
}

/**
 * Server-to-server call to the ReadIn API. `API_URL` is a SERVER-ONLY env var
 * (never NEXT_PUBLIC_*), e.g. https://readin-ehzw.onrender.com/api/v1
 * The API can be asleep on a free host, so the timeout is generous.
 */
export const callApi = async (
  path: string,
  opts: { method?: string; token?: string; json?: unknown } = {},
): Promise<Upstream> => {
  const base = apiBase(process.env.API_URL)
  if (!base) {
    return { status: 500, body: { message: 'API_URL is not configured on the admin server.' } }
  }
  const headers: Record<string, string> = {
    accept: 'application/json',
    'content-type': 'application/json',
  }
  if (opts.token) headers.authorization = `Bearer ${opts.token}`

  try {
    const res = await fetch(`${base}/${path}`, {
      method: opts.method ?? 'GET',
      headers,
      body: opts.json === undefined ? undefined : JSON.stringify(opts.json),
      cache: 'no-store',
      signal: AbortSignal.timeout(60_000),
    })
    const text = await res.text()
    let body: unknown = null
    try {
      body = text ? JSON.parse(text) : null
    } catch {
      body = null // an HTML error page etc. — never forwarded to the browser
    }
    return { status: res.status, body }
  } catch {
    return {
      status: 504,
      body: { message: 'The ReadIn server did not answer. It may be waking up — try again in a moment.' },
    }
  }
}
