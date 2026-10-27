/**
 * Pure access rules for premium / trial features (no database, no Express).
 * Unit-tested in tests/entitlements.test.mjs — keep it dependency-free.
 */

export const FEATURE_KEYS = ['habits'] as const
export type FeatureKey = (typeof FEATURE_KEYS)[number]

export const isFeatureKey = (k: string): k is FeatureKey =>
  (FEATURE_KEYS as readonly string[]).includes(k)

export interface FeatureConfig {
  /** Master switch: when false nobody except admins can use the feature. */
  enabled: boolean
  /** Free-trial length for signed-in users (0 = no trial). */
  trialDays: number
  /** Premium subscribers get the feature without a trial. */
  includedInPremium: boolean
  /** Everybody (signed-in) can use it for free, no trial and no Premium needed. */
  freeForAll: boolean
}

export const DEFAULT_FEATURES: Record<FeatureKey, FeatureConfig> = {
  habits: { enabled: true, trialDays: 14, includedInPremium: true, freeForAll: false },
}

/** What the admin changed for ONE user and ONE feature. */
export interface UserFeatureState {
  trialStartedAt: Date | null
  /** Admin gift: full access until this date. */
  grantedUntil: Date | null
  /** Admin block: no access at all. */
  revoked: boolean
}

export type AccessState =
  | 'full' // premium, admin or admin-granted
  | 'trial' // inside the free trial
  | 'trial_available' // trial not started yet
  | 'expired' // trial over
  | 'locked' // no trial and not premium, or revoked
  | 'disabled' // switched off globally

export interface Access {
  state: AccessState
  /** The feature may be used right now. */
  allowed: boolean
  /** The client may call "start trial". */
  canStartTrial: boolean
  reason: string
  trialEndsAt: string | null
  daysLeft: number | null
  grantedUntil: string | null
}

const DAY_MS = 24 * 60 * 60 * 1000

export const evaluateAccess = (input: {
  role: 'user' | 'admin'
  plan: 'free' | 'premium'
  config: FeatureConfig
  uf: UserFeatureState | null
  now?: Date
}): Access => {
  const now = input.now ?? new Date()
  const { role, plan, config, uf } = input

  const base: Access = {
    state: 'locked',
    allowed: false,
    canStartTrial: false,
    reason: '',
    trialEndsAt: null,
    daysLeft: null,
    grantedUntil: uf?.grantedUntil ? uf.grantedUntil.toISOString() : null,
  }

  if (role === 'admin') {
    return { ...base, state: 'full', allowed: true, reason: 'admin' }
  }
  if (!config.enabled) {
    return { ...base, state: 'disabled', reason: 'This feature is switched off.' }
  }
  if (uf?.revoked) {
    return { ...base, state: 'locked', reason: 'Access was removed by an administrator.' }
  }
  if (config.freeForAll) {
    return { ...base, state: 'full', allowed: true, reason: 'free for everyone' }
  }
  if (uf?.grantedUntil && uf.grantedUntil.getTime() > now.getTime()) {
    return { ...base, state: 'full', allowed: true, reason: 'granted' }
  }
  if (plan === 'premium' && config.includedInPremium) {
    return { ...base, state: 'full', allowed: true, reason: 'premium' }
  }
  if (config.trialDays <= 0) {
    return { ...base, state: 'locked', reason: 'This feature is part of Premium.' }
  }
  if (!uf?.trialStartedAt) {
    return {
      ...base,
      state: 'trial_available',
      canStartTrial: true,
      reason: `${config.trialDays}-day free trial available.`,
    }
  }
  const end = new Date(uf.trialStartedAt.getTime() + config.trialDays * DAY_MS)
  if (now.getTime() < end.getTime()) {
    return {
      ...base,
      state: 'trial',
      allowed: true,
      reason: 'free trial',
      trialEndsAt: end.toISOString(),
      daysLeft: Math.max(1, Math.ceil((end.getTime() - now.getTime()) / DAY_MS)),
    }
  }
  return {
    ...base,
    state: 'expired',
    reason: 'Your free trial has ended.',
    trialEndsAt: end.toISOString(),
    daysLeft: 0,
  }
}

/** Merge what the admin saved over the built-in defaults, sanitising values. */
export const mergeFeatureConfig = (
  saved: Partial<Record<string, Partial<FeatureConfig>>> | null | undefined,
): Record<FeatureKey, FeatureConfig> => {
  const out = {} as Record<FeatureKey, FeatureConfig>
  for (const key of FEATURE_KEYS) {
    const d = DEFAULT_FEATURES[key]
    const s = saved?.[key] ?? {}
    const days = typeof s.trialDays === 'number' && Number.isFinite(s.trialDays) ? s.trialDays : d.trialDays
    out[key] = {
      enabled: typeof s.enabled === 'boolean' ? s.enabled : d.enabled,
      trialDays: Math.min(365, Math.max(0, Math.round(days))),
      includedInPremium:
        typeof s.includedInPremium === 'boolean' ? s.includedInPremium : d.includedInPremium,
      freeForAll: typeof s.freeForAll === 'boolean' ? s.freeForAll : d.freeForAll,
    }
  }
  return out
}
