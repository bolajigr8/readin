import { AppConfig } from '../models/appConfig.model.js'
import { UserFeature } from '../models/userFeature.model.js'
import { User } from '../models/user.model.js'
import {
  evaluateAccess,
  mergeFeatureConfig,
  type Access,
  type FeatureConfig,
  type FeatureKey,
  type UserFeatureState,
} from './entitlements.logic.js'

export * from './entitlements.logic.js'

// ── Remote config (admin-editable), cached for 30 s ───────────────────────────

let cache: { at: number; value: Record<FeatureKey, FeatureConfig> } | null = null

export const invalidateFeatureConfig = (): void => {
  cache = null
}

export const getFeatureConfig = async (): Promise<Record<FeatureKey, FeatureConfig>> => {
  if (cache && Date.now() - cache.at < 30_000) return cache.value
  const doc = await AppConfig.findOne({ key: 'features' }).lean()
  const value = mergeFeatureConfig(
    (doc?.features ?? null) as Partial<Record<string, Partial<FeatureConfig>>> | null,
  )
  cache = { at: Date.now(), value }
  return value
}

// ── Who is asking ─────────────────────────────────────────────────────────────

export interface Actor {
  id: string
  role: 'user' | 'admin'
  plan: 'free' | 'premium'
  disabled: boolean
  email: string
}

/** Always read from the database — a token can be up to 15 minutes old. */
export const loadActor = async (userId: string): Promise<Actor | null> => {
  const u = await User.findById(userId).select('role plan disabled email').lean()
  if (!u) return null
  return {
    id: String(u._id),
    role: u.role === 'admin' ? 'admin' : 'user',
    plan: u.plan === 'premium' ? 'premium' : 'free',
    disabled: u.disabled === true,
    email: u.email,
  }
}

export const toState = (
  doc: { trialStartedAt?: Date | null; grantedUntil?: Date | null; revoked?: boolean } | null | undefined,
): UserFeatureState | null =>
  doc
    ? {
        trialStartedAt: doc.trialStartedAt ?? null,
        grantedUntil: doc.grantedUntil ?? null,
        revoked: doc.revoked === true,
      }
    : null

export const accessFor = async (actor: Actor, key: FeatureKey): Promise<Access> => {
  const [config, uf] = await Promise.all([
    getFeatureConfig(),
    UserFeature.findOne({ userId: actor.id, key }).lean(),
  ])
  return evaluateAccess({ role: actor.role, plan: actor.plan, config: config[key], uf: toState(uf) })
}
