/**
 * Pure decision logic for RevenueCat webhook events (no database, no Express).
 * Unit-tested in tests/revenuecat.test.mjs.
 *
 * Why not just "purchase → premium, cancellation → free"?
 *  • CANCELLATION usually only means "auto-renew was switched off": the user has
 *    paid until the end of the period and must keep Premium until EXPIRATION.
 *  • Events can arrive late or out of order → we ignore anything older than the
 *    last event we applied.
 *  • RevenueCat may identify a user by an anonymous id or an alias → we look for
 *    the first id that is really one of ours.
 */

export interface RcEvent {
  type?: string
  app_user_id?: string
  original_app_user_id?: string
  aliases?: string[]
  expiration_at_ms?: number | null
  event_timestamp_ms?: number | null
  cancel_reason?: string | null
}

export interface CurrentPremium {
  premiumUntil: Date | null
  premiumEventAt: Date | null
}

export type Decision =
  | { action: 'ignore'; reason: string }
  | { action: 'set'; plan: 'free' | 'premium'; premiumUntil: Date | null; eventAt: Date }

const GRANT = new Set([
  'INITIAL_PURCHASE',
  'RENEWAL',
  'UNCANCELLATION',
  'PRODUCT_CHANGE',
  'NON_RENEWING_PURCHASE',
])

/** First of [app_user_id, original_app_user_id, aliases…] that satisfies `isOurs`. */
export const pickUserId = (e: RcEvent, isOurs: (id: string) => boolean): string | null => {
  const candidates = [e.app_user_id, e.original_app_user_id, ...(e.aliases ?? [])]
  for (const c of candidates) {
    if (typeof c === 'string' && isOurs(c)) return c
  }
  return null
}

export const decide = (e: RcEvent, cur: CurrentPremium, now: Date): Decision => {
  const type = e.type ?? ''
  const eventAt =
    typeof e.event_timestamp_ms === 'number' && Number.isFinite(e.event_timestamp_ms)
      ? new Date(e.event_timestamp_ms)
      : now
  if (cur.premiumEventAt && eventAt.getTime() < cur.premiumEventAt.getTime()) {
    return { action: 'ignore', reason: 'older than the last applied event' }
  }
  const exp =
    typeof e.expiration_at_ms === 'number' && Number.isFinite(e.expiration_at_ms)
      ? new Date(e.expiration_at_ms)
      : null

  if (GRANT.has(type)) {
    if (exp && exp.getTime() <= now.getTime()) {
      return { action: 'set', plan: 'free', premiumUntil: exp, eventAt }
    }
    return { action: 'set', plan: 'premium', premiumUntil: exp, eventAt }
  }

  if (type === 'CANCELLATION') {
    const refunded = e.cancel_reason === 'CUSTOMER_SUPPORT'
    if (refunded || (exp && exp.getTime() <= now.getTime())) {
      return { action: 'set', plan: 'free', premiumUntil: exp ?? now, eventAt }
    }
    return { action: 'ignore', reason: 'auto-renew off: access continues until expiration' }
  }

  if (type === 'EXPIRATION') {
    return { action: 'set', plan: 'free', premiumUntil: exp ?? now, eventAt }
  }

  return { action: 'ignore', reason: `event ${type || '(none)'} does not change the plan` }
}
