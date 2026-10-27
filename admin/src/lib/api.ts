export class ApiError extends Error {
  status: number
  constructor(message: string, status: number) {
    super(message)
    this.name = 'ApiError'
    this.status = status
  }
}

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH'

interface ApiPayload {
  success?: boolean
  message?: string
  data?: unknown
}

/**
 * Calls the admin API through our own server (/api/admin/*). The browser never
 * sees a token: the session lives in httpOnly cookies.
 * A 401 sends you back to the sign-in page.
 */
export async function api<T>(path: string, init: { method?: Method; body?: unknown } = {}): Promise<T> {
  const method = init.method ?? 'GET'
  let res: Response
  try {
    res = await fetch(`/api/admin/${path}`, {
      method,
      headers: { 'content-type': 'application/json', 'x-requested-with': 'admin' },
      body: method === 'GET' || init.body === undefined ? undefined : JSON.stringify(init.body),
      cache: 'no-store',
    })
  } catch {
    throw new ApiError('Network error — check your connection.', 0)
  }

  let payload: ApiPayload | null = null
  try {
    payload = (await res.json()) as ApiPayload
  } catch {
    payload = null
  }

  if (res.status === 401) {
    if (typeof window !== 'undefined' && window.location.pathname !== '/login') {
      window.location.assign('/login')
    }
    throw new ApiError(payload?.message ?? 'Not signed in.', 401)
  }
  if (!res.ok || !payload || payload.success === false) {
    throw new ApiError(payload?.message ?? `Request failed (${res.status}).`, res.status)
  }
  return payload.data as T
}
