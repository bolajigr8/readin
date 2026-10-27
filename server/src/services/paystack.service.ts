import { createHmac, timingSafeEqual } from 'node:crypto'

/** Test-only override (ignored in production): lets automated tests use a fake Paystack. */
const base = (): string =>
  process.env['NODE_ENV'] !== 'production' && process.env['PAYSTACK_BASE_URL']
    ? process.env['PAYSTACK_BASE_URL']
    : 'https://api.paystack.co'

const secret = (): string => (process.env['PAYSTACK_SECRET_KEY'] ?? '').trim()

export const paystackConfigured = (): boolean => /^sk_(test|live)_[A-Za-z0-9]+$/.test(secret())

export const paystackMode = (): 'test' | 'live' | 'not configured' => {
  const s = secret()
  if (s.startsWith('sk_live_')) return 'live'
  if (s.startsWith('sk_test_')) return 'test'
  return 'not configured'
}

/** Public base URL of THIS server (used for the payment return page). */
export const publicBaseUrl = (): string =>
  (process.env['APP_URL'] ?? 'http://localhost:5000').trim().replace(/\/+$/, '')

export interface PaystackResult<T> {
  ok: boolean
  status: number
  message: string
  data: T | null
}

const call = async <T>(path: string, init: { method?: string; body?: unknown } = {}): Promise<PaystackResult<T>> => {
  try {
    const res = await fetch(`${base()}${path}`, {
      method: init.method ?? 'GET',
      headers: {
        authorization: `Bearer ${secret()}`,
        'content-type': 'application/json',
        accept: 'application/json',
      },
      ...(init.body === undefined ? {} : { body: JSON.stringify(init.body) }),
      signal: AbortSignal.timeout(25_000),
    })
    const json = (await res.json().catch(() => null)) as { status?: boolean; message?: string; data?: T } | null
    return {
      ok: res.ok && json?.status === true,
      status: res.status,
      message: json?.message ?? `Paystack answered HTTP ${res.status}`,
      data: json?.data ?? null,
    }
  } catch (err) {
    console.error('[paystack] request failed:', err)
    return { ok: false, status: 0, message: 'Could not reach Paystack. Try again in a moment.', data: null }
  }
}

export interface InitData {
  authorization_url: string
  access_code: string
  reference: string
}

export const initializeTransaction = (input: {
  email: string
  amountKobo: number
  reference: string
  callbackUrl: string
  metadata: Record<string, unknown>
}) =>
  call<InitData>('/transaction/initialize', {
    method: 'POST',
    body: {
      email: input.email,
      amount: input.amountKobo,
      currency: 'NGN',
      reference: input.reference,
      callback_url: input.callbackUrl,
      metadata: input.metadata,
    },
  })

export interface VerifyData {
  id: number
  status: string
  reference: string
  amount: number
  currency: string
  channel?: string
  paid_at?: string | null
  gateway_response?: string
}

export const verifyTransaction = (reference: string) =>
  call<VerifyData>(`/transaction/verify/${encodeURIComponent(reference)}`)

/**
 * Paystack signs every webhook: x-paystack-signature = HMAC-SHA512(raw body, secret key).
 * Compared in constant time. The RAW bytes are required (not re-serialised JSON).
 */
export const verifyWebhookSignature = (raw: Buffer | undefined, signature: string | undefined): boolean => {
  if (!raw || !signature || !secret()) return false
  const expected = createHmac('sha512', secret()).update(raw).digest('hex')
  const a = Buffer.from(expected, 'utf8')
  const b = Buffer.from(signature.trim().toLowerCase(), 'utf8')
  return a.length === b.length && timingSafeEqual(a, b)
}
