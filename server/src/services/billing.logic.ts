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
  /** Free Premium trial for new accounts, once per account (0 = off). */
  trialDays: number
  /** When users are reminded that Premium is ending / has ended. */
  reminders: ReminderConfig
  /** Wording on the Premium screen. */
  marketing: MarketingConfig
}

/**
 * One reminder moment, relative to the day Premium ends:
 * -5 = five days before, 0 = the day it ends, 3 = three days after.
 */
export interface ReminderStep {
  offsetDays: number
  inApp: boolean
  email: boolean
}

export interface ReminderConfig {
  enabled: boolean
  steps: ReminderStep[]
}

export interface MarketingConfig {
  /** Big line on the Premium screen; empty = the app's default text. */
  headline: string
  /** Show "less than ₦24 a day" under each plan. */
  showPerDay: boolean
  /** Show "2 months free · save ₦1,400" on longer plans. */
  showSavings: boolean
}

export const MAX_REMINDER_STEPS = 6
export const MIN_REMINDER_OFFSET = -30
export const MAX_REMINDER_OFFSET = 30
export const MAX_TRIAL_DAYS = 90

export const DEFAULT_REMINDERS: ReminderConfig = {
  enabled: true,
  steps: [
    { offsetDays: -5, inApp: true, email: true },
    { offsetDays: -2, inApp: true, email: true },
    { offsetDays: 0, inApp: true, email: true },
    { offsetDays: 3, inApp: true, email: true },
  ],
}

export const DEFAULT_MARKETING: MarketingConfig = { headline: '', showPerDay: true, showSavings: true }

export const MAX_PLANS = 6
export const MIN_PRICE_KOBO = 5_000 // ₦50
export const MAX_PRICE_KOBO = 500_000_000 // ₦5,000,000

export const DEFAULT_BILLING: BillingConfig = {
  enabled: false,
  currency: 'NGN',
  plans: [],
  freeLibraryLimit: 10,
  trialDays: 0,
  reminders: DEFAULT_REMINDERS,
  marketing: DEFAULT_MARKETING,
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
    trialDays: int(s['trialDays'], 0, MAX_TRIAL_DAYS, 0),
    reminders: mergeReminders(s['reminders']),
    marketing: mergeMarketing(s['marketing']),
  }
}

/** Clean reminder steps: unique offsets, sorted, within limits. */
export const normalizeReminderSteps = (raw: unknown): ReminderStep[] => {
  const seen = new Set<number>()
  const out: ReminderStep[] = []
  for (const r of Array.isArray(raw) ? (raw as unknown[]) : []) {
    if (!r || typeof r !== 'object') continue
    const o = r as Record<string, unknown>
    if (typeof o['offsetDays'] !== 'number' || !Number.isFinite(o['offsetDays'])) continue
    const offsetDays = int(o['offsetDays'], MIN_REMINDER_OFFSET, MAX_REMINDER_OFFSET, 0)
    if (seen.has(offsetDays)) continue
    seen.add(offsetDays)
    out.push({ offsetDays, inApp: o['inApp'] !== false, email: o['email'] !== false })
  }
  return out.sort((a, b) => a.offsetDays - b.offsetDays).slice(0, MAX_REMINDER_STEPS)
}

const mergeReminders = (raw: unknown): ReminderConfig => {
  if (!raw || typeof raw !== 'object') return DEFAULT_REMINDERS
  const o = raw as Record<string, unknown>
  return {
    enabled: o['enabled'] !== false,
    steps: Array.isArray(o['steps']) ? normalizeReminderSteps(o['steps']) : DEFAULT_REMINDERS.steps,
  }
}

const mergeMarketing = (raw: unknown): MarketingConfig => {
  if (!raw || typeof raw !== 'object') return DEFAULT_MARKETING
  const o = raw as Record<string, unknown>
  return {
    headline: str(o['headline'], 80),
    showPerDay: o['showPerDay'] !== false,
    showSavings: o['showSavings'] !== false,
  }
}

/** What the mobile app may see: only active plans, nothing else. Extra fields are ignored by older apps. */
export const publicBilling = (cfg: BillingConfig) => {
  const active = cfg.plans.filter((p) => p.active)
  return {
    enabled: cfg.enabled,
    currency: cfg.currency,
    freeLibraryLimit: cfg.freeLibraryLimit,
    trialDays: cfg.trialDays,
    headline: cfg.marketing.headline,
    /** Offsets (days from the end of Premium) at which the app shows its banner. */
    reminders: cfg.reminders.enabled ? cfg.reminders.steps.filter((s) => s.inApp).map((s) => s.offsetDays) : [],
    plans: cfg.enabled
      ? active.map((p) => ({
          id: p.id,
          name: p.name,
          description: p.description,
          priceKobo: p.priceKobo,
          durationDays: p.durationDays,
          badge: p.badge,
          perDayText: cfg.marketing.showPerDay ? perDayText(p.priceKobo, p.durationDays) : '',
          savingsText: cfg.marketing.showSavings ? savingsText(p, active) : '',
        }))
      : [],
  }
}

/** The hook texts of every ACTIVE plan (admin preview; same texts the app gets). */
export const planHooks = (cfg: BillingConfig): { id: string; perDayText: string; savingsText: string }[] => {
  const active = cfg.plans.filter((p) => p.active)
  return active.map((p) => ({
    id: p.id,
    perDayText: cfg.marketing.showPerDay ? perDayText(p.priceKobo, p.durationDays) : '',
    savingsText: cfg.marketing.showSavings ? savingsText(p, active) : '',
  }))
}

/** Whole months in a plan (30 → 1, 365 → 12); 0 for plans shorter than ~4 weeks. */
export const planMonths = (durationDays: number): number => (durationDays >= 28 ? Math.round(durationDays / 30.4) : 0)

/** "less than ₦24 a day" (or "just ₦20 a day" when it divides exactly into whole naira). */
export const perDayText = (priceKobo: number, durationDays: number): string => {
  if (durationDays < 1 || priceKobo <= 0) return ''
  const perDayKobo = priceKobo / durationDays
  if (Number.isInteger(perDayKobo) && perDayKobo % 100 === 0) return `just ${formatNaira(perDayKobo)} a day`
  return `less than ${formatNaira(Math.ceil(perDayKobo / 100) * 100)} a day`
}

/**
 * Saving of a longer plan compared with paying a shorter plan again and again:
 * ₦7,000/year vs ₦700/month → "2 months free · save ₦1,400". Empty when there is no saving.
 */
export const savingsText = (
  plan: Pick<Plan, 'priceKobo' | 'durationDays'>,
  plans: Pick<Plan, 'priceKobo' | 'durationDays'>[],
): string => {
  const months = planMonths(plan.durationDays)
  if (months < 2) return ''
  const base = plans
    .filter((p) => planMonths(p.durationDays) >= 1 && planMonths(p.durationDays) < months)
    .sort((a, b) => a.durationDays - b.durationDays || a.priceKobo - b.priceKobo)[0]
  if (!base) return ''
  const monthly = base.priceKobo / planMonths(base.durationDays)
  const saving = Math.round(monthly * months - plan.priceKobo)
  if (saving < 100) return ''
  const save = `save ${formatNaira(Math.round(saving / 100) * 100)}`
  const freeMonths = saving / monthly
  if (Number.isInteger(freeMonths)) return `${freeMonths} month${freeMonths === 1 ? '' : 's'} free · ${save}`
  return `${save} (${Math.round((saving / (monthly * months)) * 100)}% off)`
}

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

// ── Premium reminders & trial ────────────────────────────────────────────────

/** A reminder is identified by its step AND the end date it was about (a renewal starts fresh). */
export const reminderKey = (offsetDays: number, premiumUntil: Date): string =>
  `${offsetDays}@${premiumUntil.toISOString()}`

/** E-mails more than this late are skipped (server asleep, steps changed later, Premium given long ago). */
export const REMINDER_STALE_MS = 2 * DAY_MS

/**
 * The reminder e-mail to send now, or null. Only the LATEST step that is due is sent (never several at
 * once); earlier missed steps are skipped.
 */
export const dueEmailReminder = (
  premiumUntil: Date | null,
  now: Date,
  cfg: ReminderConfig,
  sent: readonly string[],
): ReminderStep | null => {
  if (!premiumUntil || !cfg.enabled) return null
  const due = cfg.steps
    .filter((s) => s.email)
    .filter((s) => {
      const at = premiumUntil.getTime() + s.offsetDays * DAY_MS
      return now.getTime() >= at && now.getTime() - at < REMINDER_STALE_MS
    })
    .sort((a, b) => b.offsetDays - a.offsetDays)[0]
  if (!due || sent.includes(reminderKey(due.offsetDays, premiumUntil))) return null
  return due
}

/** premiumUntil range in which a reminder e-mail can be due now — picks candidate users from the database. */
export const reminderWindow = (cfg: ReminderConfig, now: Date): { from: Date; to: Date } | null => {
  const steps = cfg.steps.filter((s) => s.email)
  if (!cfg.enabled || steps.length === 0) return null
  const min = Math.min(...steps.map((s) => s.offsetDays))
  const max = Math.max(...steps.map((s) => s.offsetDays))
  // due when premiumUntil + offset <= now < premiumUntil + offset + stale
  return {
    from: new Date(now.getTime() - max * DAY_MS - REMINDER_STALE_MS),
    to: new Date(now.getTime() - min * DAY_MS),
  }
}

export type InAppReminder =
  | { kind: 'before'; daysLeft: number; premiumUntil: string }
  | { kind: 'today'; premiumUntil: string }
  | { kind: 'after'; daysAgo: number; premiumUntil: string }

/**
 * What the in-app banner should say now (null = no banner). Shown from the first in-app step until 7 days
 * after the last step, never more than 30 days after Premium ended.
 */
export const inAppReminder = (
  premiumUntil: Date | null,
  now: Date,
  offsets: readonly number[],
): InAppReminder | null => {
  if (!premiumUntil || offsets.length === 0) return null
  const end = premiumUntil.getTime()
  const t = now.getTime()
  const first = end + Math.min(...offsets) * DAY_MS
  const last = end + Math.max(...offsets) * DAY_MS
  if (t < first || t > last + 7 * DAY_MS || t > end + 30 * DAY_MS) return null
  const iso = premiumUntil.toISOString()
  if (t < end) {
    const daysLeft = Math.ceil((end - t) / DAY_MS)
    return daysLeft <= 1 ? { kind: 'today', premiumUntil: iso } : { kind: 'before', daysLeft, premiumUntil: iso }
  }
  const daysAgo = Math.floor((t - end) / DAY_MS)
  return daysAgo === 0 ? { kind: 'today', premiumUntil: iso } : { kind: 'after', daysAgo, premiumUntil: iso }
}

export type PremiumKind = 'paid' | 'trial' | 'gift'

/** Whether a free trial may start for this account (the server re-checks atomically when starting it). */
export const trialAvailable = (
  cfg: Pick<BillingConfig, 'trialDays'>,
  user: { plan: 'free' | 'premium'; premiumUntil: Date | null; premiumTrialUsedAt: Date | null },
  hasPaid: boolean,
  now: Date,
): boolean =>
  cfg.trialDays > 0 &&
  !user.premiumTrialUsedAt &&
  !hasPaid &&
  effectivePlan(user.plan, user.premiumUntil, now) === 'free'
