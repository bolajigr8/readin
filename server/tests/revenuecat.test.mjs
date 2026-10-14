// Run: node --experimental-strip-types tests/revenuecat.test.mjs   (Node 22+)
import assert from 'node:assert/strict'
import { decide, pickUserId } from '../src/services/revenuecat.logic.ts'

const now = new Date('2026-10-20T12:00:00Z')
const day = 86400000
const none = { premiumUntil: null, premiumEventAt: null }
let n = 0
const t = (name, fn) => { fn(); n++; console.log('ok -', name) }

t('purchase / renewal → premium until the expiration date', () => {
  for (const type of ['INITIAL_PURCHASE', 'RENEWAL', 'UNCANCELLATION', 'PRODUCT_CHANGE']) {
    const d = decide({ type, expiration_at_ms: now.getTime() + 30 * day }, none, now)
    assert.equal(d.action, 'set'); assert.equal(d.plan, 'premium')
    assert.equal(d.premiumUntil.getTime(), now.getTime() + 30 * day)
  }
})
t('an already-expired purchase event does not grant premium', () => {
  const d = decide({ type: 'RENEWAL', expiration_at_ms: now.getTime() - day }, none, now)
  assert.equal(d.plan, 'free')
})
t('CANCELLATION (auto-renew off) keeps premium until it expires', () => {
  const d = decide({ type: 'CANCELLATION', cancel_reason: 'UNSUBSCRIBE', expiration_at_ms: now.getTime() + 10 * day }, none, now)
  assert.equal(d.action, 'ignore')
})
t('CANCELLATION because of a refund removes premium immediately', () => {
  const d = decide({ type: 'CANCELLATION', cancel_reason: 'CUSTOMER_SUPPORT', expiration_at_ms: now.getTime() + 10 * day }, none, now)
  assert.equal(d.action, 'set'); assert.equal(d.plan, 'free')
})
t('EXPIRATION → free', () => {
  const d = decide({ type: 'EXPIRATION', expiration_at_ms: now.getTime() - 1000 }, none, now)
  assert.equal(d.plan, 'free')
})
t('stale (out-of-order) events are ignored', () => {
  const cur = { premiumUntil: null, premiumEventAt: new Date(now.getTime()) }
  const d = decide({ type: 'EXPIRATION', event_timestamp_ms: now.getTime() - 5000 }, cur, now)
  assert.equal(d.action, 'ignore')
  const newer = decide({ type: 'RENEWAL', event_timestamp_ms: now.getTime() + 5000, expiration_at_ms: now.getTime() + day }, cur, now)
  assert.equal(newer.action, 'set')
})
t('events that must not change the plan', () => {
  for (const type of ['BILLING_ISSUE', 'SUBSCRIBER_ALIAS', 'TRANSFER', 'TEST', 'SUBSCRIPTION_PAUSED', undefined]) {
    assert.equal(decide({ type }, none, now).action, 'ignore', String(type))
  }
})
t('user id: first id that is really ours (anonymous ids are skipped)', () => {
  const ours = (s) => /^[a-f0-9]{24}$/.test(s)
  const id = 'b'.repeat(24)
  assert.equal(pickUserId({ app_user_id: '$RCAnonymousID:abc', aliases: ['$RCAnonymousID:abc', id] }, ours), id)
  assert.equal(pickUserId({ app_user_id: id }, ours), id)
  assert.equal(pickUserId({ app_user_id: '$RCAnonymousID:abc' }, ours), null)
  assert.equal(pickUserId({}, ours), null)
})
console.log(`\n${n} tests passed`)
