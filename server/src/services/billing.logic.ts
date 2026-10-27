/**
 * Pure billing rules (no database, no Express): plans, prices (kobo), premium
 * periods and plan expiry. Unit-tested in tests/billing.test.mjs.
 *
 * Money: everything is stored in KOBO (1 naira = 100 kobo) as whole numbers — the
 * unit Paystack uses — so there are never rounding errors.
 */

export interface Plan {
  id: string
  name: string
  description: string
  /** Price in kobo (₦1,500 = 150000). */
  priceKobo: number
  /** How long Premium lasts after one payment. */
  durationDays: number
  /** Inactive plans are hidden from users (kept for history). */
  active: boolean
  /** Optional small label on the plan card, e.g. "Best value". */
  badge: string
}

export interface BillingConfig {
  /** Master switch: payments (and Premium upsell) visible in the app. */
  enabled: boolean
  currency: 'NGN'
  plans: Plan[]
  /** Books a Free user may keep in the library. */
  freeLibraryLimit: number
}

export const MAX_PLANS = 6
export const MIN_PRICE_KOBO = 5_000 // ₦50
export const MAX_PRICE_KOBO = 500_000_000 // ₦5,000,000

export const DEFAULT_BILLING: BillingConfig = {
  enabled: false,
  currency: 'NGN',
  plans: [],
  freeLibraryLimit: 10,
}

const str = (v: unknown, max: number): string => (typeof v === 'string' ? v.trim().slice(0, max) : '')

const int = (v: unknown, min: number, max: number, fallback: number): number => {
  const n = typeof v === 'number' && Number.isFinite(v) ? Math.round(v) : fallback
  return Math.min(max, Math.max(min, n))
}

export const slug = (name: string): string =>
  name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 24) || 'plan'

/** A unique id for a new plan: the name's slug (+ a number if taken). */
export const makePlanId = (name: string, taken: Iterable<string>): string => {
  const used = new Set(taken)
  const base = slug(name)
  if (!used.has(base)) return base
  for (let i = 2; i < 100; i++) if (!used.has(`${base}-${i}`)) return `${base}-${i}`
  return `${base}-${Date.now().toString(36)}`
}

/** Reads whatever is stored (tolerant) into a clean BillingConfig. */
export const mergeBilling = (saved: unknown): BillingConfig => {
  const s = (saved && typeof saved === 'object' ? saved : {}) as Record<string, unknown>
  const plans: Plan[] = []
  const ids = new Set<string>()
  for (const raw of Array.isArray(s['plans']) ? (s['plans'] as unknown[]) : []) {
    if (!raw || typeof raw !== 'object') continue
    const r = raw as Record<string, unknown>
    const name = str(r['name'], 40)
    const price = int(r['priceKobo'], MIN_PRICE_KOBO, MAX_PRICE_KOBO, 0)
    if (!name || typeof r['priceKobo'] !== 'number') continue
    let id = str(r['id'], 40)
    if (!id || ids.has(id)) id = makePlanId(name, ids)
    ids.add(id)
    plans.push({
      id,
      name,
      description: str(r['description'], 120),
      priceKobo: price,
      durationDays: int(r['durationDays'], 1, 3650, 30),
      active: r['active'] !== false,
      badge: str(r['badge'], 20),
    })
    if (plans.length >= MAX_PLANS) break
  }
  return {
    enabled: s['enabled'] === true,
    currency: 'NGN',
    plans,
    freeLibraryLimit: int(s['freeLibraryLimit'], 1, 1000, DEFAULT_BILLING.freeLibraryLimit),
  }
}

/** What the mobile app may see: only active plans, nothing else. */
export const publicBilling = (cfg: BillingConfig) => ({
  enabled: cfg.enabled,
  currency: cfg.currency,
  freeLibraryLimit: cfg.freeLibraryLimit,
  plans: cfg.enabled
    ? cfg.plans
        .filter((p) => p.active)
        .map((p) => ({
          id: p.id,
          name: p.name,
          description: p.description,
          priceKobo: p.priceKobo,
          durationDays: p.durationDays,
          badge: p.badge,
        }))
    : [],
})

/** "₦1,500" / "₦1,500.50" from kobo. */
export const formatNaira = (kobo: number): string => {
  const naira = Math.floor(kobo / 100)
  const rest = kobo % 100
  const whole = naira.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')
  return `₦${whole}${rest ? `.${rest.toString().padStart(2, '0')}` : ''}`
}

const DAY_MS = 86_400_000

/** Premium after a payment: the new period is added AFTER any time still left. */
export const computePremiumUntil = (current: Date | null, now: Date, days: number): Date => {
  const start = current && current.getTime() > now.getTime() ? current : now
  return new Date(start.getTime() + days * DAY_MS)
}

/**
 * The plan a user effectively has right now. Premium with an end date that has
 * passed is Free; Premium without an end date (given by an admin) lasts until
 * an admin changes it.
 */
export const effectivePlan = (
  plan: 'free' | 'premium',
  premiumUntil: Date | null,
  now: Date,
): 'free' | 'premium' => {
  if (plan !== 'premium') return 'free'
  if (premiumUntil && premiumUntil.getTime() <= now.getTime()) return 'free'
  return 'premium'
}

export interface PlanInput {
  id?: string | undefined
  name: string
  description?: string | undefined
  priceKobo: number
  durationDays: number
  active: boolean
  badge?: string | undefined
}

/** Admin input → clean plans with unique ids (existing ids are kept). */
export const normalizePlansInput = (input: PlanInput[]): Plan[] => {
  const out: Plan[] = []
  const ids = new Set<string>()
  for (const p of input.slice(0, MAX_PLANS)) {
    let id = (p.id ?? '').trim()
    if (!id || ids.has(id)) id = makePlanId(p.name, ids)
    ids.add(id)
    out.push({
      id,
      name: p.name.trim().slice(0, 40),
      description: (p.description ?? '').trim().slice(0, 120),
      priceKobo: Math.round(p.priceKobo),
      durationDays: Math.round(p.durationDays),
      active: p.active,
      badge: (p.badge ?? '').trim().slice(0, 20),
    })
  }
  return out
}

/** The text users see when a Free account is full. Mentions Premium only if payments are switched on. */
export const limitMessage = (cfg: Pick<BillingConfig, 'enabled' | 'freeLibraryLimit'>): string =>
  cfg.enabled
    ? `Free plan is limited to ${cfg.freeLibraryLimit} books. Upgrade to Premium for unlimited access.`
    : `Your library is limited to ${cfg.freeLibraryLimit} books. Remove a book to add a new one.`
