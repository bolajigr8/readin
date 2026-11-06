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
  /** First part of a NON-JSON answer (e.g. a firewall page) — for the server log only. */
  raw?: string
  /** For NON-JSON answers: the page <title> and Cloudflare's Ray ID (Paystack support asks for these). */
  pageTitle?: string
  rayId?: string
}

/** One log-friendly line describing a NON-JSON (firewall) answer. Empty for normal answers. */
export const describeBlock = (r: PaystackResult<unknown>): string =>
  r.raw === undefined
    ? ''
    : `firewall page "${r.pageTitle || 'no title'}", Ray ID ${r.rayId || 'none'}, at ${new Date().toISOString()}`

const parseJson = <J>(text: string): J | null => {
  try {
    return text ? (JSON.parse(text) as J) : null
  } catch {
    return null
  }
}

const call = async <T>(path: string, init: { method?: string; body?: unknown } = {}): Promise<PaystackResult<T>> => {
  try {
    const res = await fetch(`${base()}${path}`, {
      method: init.method ?? 'GET',
      headers: {
        authorization: `Bearer ${secret()}`,
        'content-type': 'application/json',
        accept: 'application/json',
        // Paystack sits behind a firewall that can refuse requests without a normal User-Agent.
        'user-agent': 'ReadIn-Server/1.0 (+https://readin-ehzw.onrender.com)',
      },
      ...(init.body === undefined ? {} : { body: JSON.stringify(init.body) }),
      signal: AbortSignal.timeout(25_000),
    })
    const text = await res.text().catch(() => '')
    const json = parseJson<{ status?: boolean; message?: string; data?: T }>(text)
    const title = /<title[^>]*>([\s\S]*?)<\/title>/i.exec(text)?.[1]?.replace(/\s+/g, ' ').trim().slice(0, 120) ?? ''
    return {
      ok: res.ok && json?.status === true,
      status: res.status,
      message: json?.message ?? `Paystack answered HTTP ${res.status}`,
      data: json?.data ?? null,
      ...(json
        ? {}
        : {
            raw: text.replace(/\s+/g, ' ').slice(0, 300),
            pageTitle: title,
            rayId: (res.headers.get('cf-ray') ?? '').slice(0, 60),
          }),
    }
  } catch (err) {
    console.error('[paystack] request failed:', err)
    return { ok: false, status: 0, message: 'Could not reach Paystack. Try again in a moment.', data: null }
  }
}

/** Plain-words explanation of a failed Paystack answer (shown to the admin, never to users). */
export const explainPaystackFailure = (r: PaystackResult<unknown>): string => {
  if (r.status === 0) return 'The server could not reach Paystack at all (network problem or Paystack is down). Try again in a minute.'
  if (r.status === 401) {
    return 'Paystack rejected the secret key. Copy it again from Paystack → Settings → API Keys & Webhooks (no quotes, no spaces) and make sure it is the key of the SAME account, and that you are using the Test key while in test mode.'
  }
  if (r.raw !== undefined) {
    return `Paystack's firewall refused the request before it reached your account (the answer was a web page, not a Paystack message). It is tied to the server's internet address (Render's shared outbound IPs), not to your key. Send Paystack support: this ${describeBlock(r)}, your Render region and the outbound IP ranges (Render → service → Connect → Outbound).`
  }
  if (r.status === 403) return `Paystack refused the request: ${r.message}. Check that your Paystack account/business is active and that no IP restriction is set in Settings → API Keys & Webhooks.`
  if (r.status === 429) return 'Paystack says too many requests. Wait a minute and try again.'
  if (r.status >= 500) return 'Paystack had an internal problem. Try again later.'
  return r.message
}

/** Cheap authenticated call used by the admin panel's "Test connection" button. */
export const pingPaystack = () => call<unknown>('/bank?country=nigeria&perPage=1')

/**
 * Second half of "Test connection": the SAME kind of request as a real checkout
 * (POST /transaction/initialize), deliberately invalid (amount 0) so Paystack
 * refuses it with a normal JSON error and creates nothing. Paystack's firewall
 * has blocked exactly this request from Render while GET requests passed, so the
 * GET alone could say "working" while nobody could pay.
 * Reachable = Paystack itself answered (any JSON reply other than a key rejection).
 */
export const probeStartPayment = async (): Promise<{ reachable: boolean; result: PaystackResult<unknown> }> => {
  const result = await call<unknown>('/transaction/initialize', {
    method: 'POST',
    body: { email: 'connection-test@example.com', amount: 0, currency: 'NGN' },
  })
  const reachable = result.raw === undefined && result.status !== 0 && result.status !== 401 && result.status !== 403
  return { reachable, result }
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
