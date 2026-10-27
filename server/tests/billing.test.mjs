// Run: node --experimental-strip-types tests/billing.test.mjs   (Node 22+)
import assert from 'node:assert/strict'
import {
  mergeBilling, publicBilling, formatNaira, computePremiumUntil, effectivePlan,
  makePlanId, normalizePlansInput, MAX_PLANS,
} from '../src/services/billing.logic.ts'

const day = 86400000
const now = new Date('2026-10-20T12:00:00Z')
let n = 0
const t = (name, fn) => { fn(); n++; console.log('ok -', name) }

t('defaults: payments OFF, no plans, free limit 10', () => {
  const c = mergeBilling(null)
  assert.equal(c.enabled, false); assert.deepEqual(c.plans, []); assert.equal(c.freeLibraryLimit, 10)
  assert.equal(mergeBilling('junk').enabled, false)
})
t('mergeBilling cleans bad data and keeps good plans', () => {
  const c = mergeBilling({
    enabled: true, freeLibraryLimit: 99999,
    plans: [
      { id: 'monthly', name: ' Monthly ', priceKobo: 150000, durationDays: 30, active: true },
      { name: '', priceKobo: 100000 },                 // no name → dropped
      { name: 'Free?', priceKobo: 'x' },               // bad price → dropped
      { id: 'monthly', name: 'Duplicate id', priceKobo: 200000, durationDays: 7 }, // id repaired
      null, 5,
    ],
  })
  assert.equal(c.enabled, true); assert.equal(c.freeLibraryLimit, 1000)
  assert.equal(c.plans.length, 2)
  assert.equal(c.plans[0].name, 'Monthly'); assert.equal(c.plans[0].priceKobo, 150000)
  assert.notEqual(c.plans[1].id, 'monthly')
})
t('price limits are enforced (₦50 – ₦5,000,000)', () => {
  assert.equal(mergeBilling({ plans: [{ name: 'a', priceKobo: 1 }] }).plans[0].priceKobo, 5000)
  assert.equal(mergeBilling({ plans: [{ name: 'a', priceKobo: 9e12 }] }).plans[0].priceKobo, 500000000)
})
t('at most 6 plans', () => {
  const many = Array.from({ length: 10 }, (_, i) => ({ name: 'P' + i, priceKobo: 100000 + i }))
  assert.equal(mergeBilling({ plans: many }).plans.length, MAX_PLANS)
})
t('the app only sees ACTIVE plans, and none when payments are off', () => {
  const cfg = mergeBilling({ enabled: true, plans: [
    { id: 'a', name: 'A', priceKobo: 100000, durationDays: 30, active: true },
    { id: 'b', name: 'B', priceKobo: 900000, durationDays: 365, active: false },
  ] })
  assert.deepEqual(publicBilling(cfg).plans.map((p) => p.id), ['a'])
  assert.deepEqual(publicBilling({ ...cfg, enabled: false }).plans, [])
  assert.equal('active' in publicBilling(cfg).plans[0], false)
})
t('naira formatting from kobo', () => {
  assert.equal(formatNaira(150000), '₦1,500')
  assert.equal(formatNaira(150050), '₦1,500.50')
  assert.equal(formatNaira(5000), '₦50')
  assert.equal(formatNaira(123456789), '₦1,234,567.89')
})
t('a new payment extends AFTER the time that is left', () => {
  assert.equal(computePremiumUntil(null, now, 30).getTime(), now.getTime() + 30 * day)
  const left = new Date(now.getTime() + 10 * day)
  assert.equal(computePremiumUntil(left, now, 30).getTime(), left.getTime() + 30 * day)
  const past = new Date(now.getTime() - 5 * day)
  assert.equal(computePremiumUntil(past, now, 30).getTime(), now.getTime() + 30 * day)
})
t('plan expiry: ended Premium is Free; open-ended (admin) Premium stays', () => {
  assert.equal(effectivePlan('premium', new Date(now.getTime() + day), now), 'premium')
  assert.equal(effectivePlan('premium', new Date(now.getTime() - 1), now), 'free')
  assert.equal(effectivePlan('premium', null, now), 'premium')
  assert.equal(effectivePlan('free', new Date(now.getTime() + day), now), 'free')
})
t('plan ids are unique and URL-safe', () => {
  assert.equal(makePlanId('Yearly Plan!', []), 'yearly-plan')
  assert.equal(makePlanId('Yearly Plan!', ['yearly-plan']), 'yearly-plan-2')
  assert.equal(makePlanId('!!!', []), 'plan')
})
t('normalizePlansInput keeps ids and rounds money', () => {
  const p = normalizePlansInput([
    { id: 'keep', name: ' Monthly ', priceKobo: 150000.4, durationDays: 30, active: true },
    { name: 'Monthly', priceKobo: 200000, durationDays: 365, active: false, badge: 'Best value' },
  ])
  assert.equal(p[0].id, 'keep'); assert.equal(p[0].priceKobo, 150000)
  assert.equal(p[1].id, 'monthly'); assert.equal(p[1].badge, 'Best value')
})
console.log(`\n${n} tests passed`)
