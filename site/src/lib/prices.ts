// Premium prices for the website, read from the API's PUBLIC config (the same numbers the admin sets).
// Fetched once while the site is built (so the prices show instantly, even when the free API server is asleep)
// and again in the visitor's browser (so admin changes appear without rebuilding the site).

export const API_BASE = 'https://readin-ehzw.onrender.com/api/v1'
export const PUBLIC_CONFIG_URL = `${API_BASE}/config/public`

export interface PricePlan {
  id: string
  name: string
  priceText: string
  periodText: string
  perDayText: string
  savingsText: string
  badge: string
}

export interface Prices {
  plans: PricePlan[]
  trialDays: number
}

/** "₦1,500" / "₦1,500.50" from kobo (₦1 = 100 kobo). */
export const formatNaira = (kobo: number): string => {
  const naira = Math.floor(kobo / 100)
  const rest = kobo % 100
  return `₦${naira.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')}${rest ? `.${String(rest).padStart(2, '0')}` : ''}`
}

/** "a month" · "a year" · "90 days" */
export const periodText = (days: number): string => {
  if (days >= 28 && days <= 31) return 'a month'
  if (days >= 365 && days <= 366) return 'a year'
  if (days === 7) return 'a week'
  return `${days} days`
}

const str = (v: unknown): string => (typeof v === 'string' ? v : '')

/** The API answer → what the page shows; null when payments are off or there are no plans (section hidden). */
export const pickPrices = (json: unknown): Prices | null => {
  const billing = (json as { data?: { billing?: Record<string, unknown> } } | null)?.data?.billing
  if (!billing || billing['enabled'] !== true || !Array.isArray(billing['plans'])) return null
  const plans: PricePlan[] = []
  for (const raw of billing['plans'] as unknown[]) {
    if (!raw || typeof raw !== 'object') continue
    const p = raw as Record<string, unknown>
    const kobo = typeof p['priceKobo'] === 'number' ? p['priceKobo'] : 0
    const days = typeof p['durationDays'] === 'number' ? p['durationDays'] : 0
    if (kobo <= 0 || days <= 0 || !str(p['name'])) continue
    plans.push({
      id: str(p['id']) || str(p['name']),
      name: str(p['name']),
      priceText: formatNaira(kobo),
      periodText: periodText(days),
      perDayText: str(p['perDayText']),
      savingsText: str(p['savingsText']),
      badge: str(p['badge']),
    })
  }
  if (plans.length === 0) return null
  const trial = typeof billing['trialDays'] === 'number' ? billing['trialDays'] : 0
  return { plans: plans.slice(0, 4), trialDays: trial > 0 ? trial : 0 }
}

/**
 * GET the public config with a time limit (never throws).
 * `undefined` = could not ask (offline, server asleep, error) · `null` = payments are off / no plans · else the prices.
 */
export const fetchPrices = async (timeoutMs: number, atBuild = false): Promise<Prices | null | undefined> => {
  try {
    // While building a static page Next.js only allows cacheable requests; the unique `?build=` makes sure an
    // old cached answer is never reused. In the browser: always fresh.
    const res = atBuild
      ? await fetch(`${PUBLIC_CONFIG_URL}?build=${Date.now()}`, { signal: AbortSignal.timeout(timeoutMs), cache: 'force-cache' })
      : await fetch(PUBLIC_CONFIG_URL, { signal: AbortSignal.timeout(timeoutMs), cache: 'no-store' })
    if (!res.ok) return undefined
    return pickPrices(await res.json())
  } catch {
    return undefined
  }
}
