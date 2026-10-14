// Run:  node --experimental-strip-types tests/entitlements.test.mjs   (Node 22+)
import assert from 'node:assert/strict'
import { evaluateAccess, mergeFeatureConfig, DEFAULT_FEATURES } from '../src/services/entitlements.logic.ts'

const cfg = { enabled: true, trialDays: 14, includedInPremium: true }
const day = 24 * 3600 * 1000
const now = new Date('2026-10-20T12:00:00Z')
let n = 0
const t = (name, fn) => { fn(); n++; console.log('ok -', name) }
const acc = (o) => evaluateAccess({ role: 'user', plan: 'free', config: cfg, uf: null, now, ...o })

t('admin always has full access, even when disabled', () => {
  const a = acc({ role: 'admin', config: { ...cfg, enabled: false } })
  assert.equal(a.state, 'full'); assert.equal(a.allowed, true)
})
t('feature switched off → nobody (except admin)', () => {
  const a = acc({ config: { ...cfg, enabled: false }, plan: 'premium' })
  assert.equal(a.state, 'disabled'); assert.equal(a.allowed, false)
})
t('new user: trial available, not yet allowed, can start', () => {
  const a = acc({})
  assert.equal(a.state, 'trial_available'); assert.equal(a.allowed, false); assert.equal(a.canStartTrial, true)
})
t('trial: allowed, days left counts down, ends after trialDays', () => {
  const start = new Date(now.getTime() - 2 * day)
  const a = acc({ uf: { trialStartedAt: start, grantedUntil: null, revoked: false } })
  assert.equal(a.state, 'trial'); assert.equal(a.allowed, true); assert.equal(a.daysLeft, 12)
  const last = acc({ uf: { trialStartedAt: new Date(now.getTime() - 13.5 * day), grantedUntil: null, revoked: false } })
  assert.equal(last.state, 'trial'); assert.equal(last.daysLeft, 1)
})
t('after two weeks the trial is expired and access stops', () => {
  const a = acc({ uf: { trialStartedAt: new Date(now.getTime() - 14 * day), grantedUntil: null, revoked: false } })
  assert.equal(a.state, 'expired'); assert.equal(a.allowed, false); assert.equal(a.daysLeft, 0); assert.equal(a.canStartTrial, false)
})
t('premium users have full access without a trial', () => {
  const a = acc({ plan: 'premium' })
  assert.equal(a.state, 'full'); assert.equal(a.reason, 'premium')
})
t('premium not included in the feature → still needs the trial', () => {
  const a = acc({ plan: 'premium', config: { ...cfg, includedInPremium: false } })
  assert.equal(a.state, 'trial_available')
})
t('admin grant gives full access until the date, then falls back to the trial rules', () => {
  const active = acc({ uf: { trialStartedAt: new Date(now.getTime() - 30 * day), grantedUntil: new Date(now.getTime() + 5 * day), revoked: false } })
  assert.equal(active.state, 'full'); assert.equal(active.reason, 'granted')
  const over = acc({ uf: { trialStartedAt: new Date(now.getTime() - 30 * day), grantedUntil: new Date(now.getTime() - day), revoked: false } })
  assert.equal(over.state, 'expired')
})
t('revoked wins over everything except admin', () => {
  const a = acc({ plan: 'premium', uf: { trialStartedAt: null, grantedUntil: new Date(now.getTime() + day), revoked: true } })
  assert.equal(a.state, 'locked'); assert.equal(a.allowed, false)
  assert.equal(acc({ role: 'admin', uf: { trialStartedAt: null, grantedUntil: null, revoked: true } }).state, 'full')
})
t('no trial configured → locked for free users', () => {
  const a = acc({ config: { ...cfg, trialDays: 0 } })
  assert.equal(a.state, 'locked')
})
t('changing trialDays in the admin panel affects running trials', () => {
  const uf = { trialStartedAt: new Date(now.getTime() - 20 * day), grantedUntil: null, revoked: false }
  assert.equal(acc({ uf }).state, 'expired')
  assert.equal(acc({ uf, config: { ...cfg, trialDays: 30 } }).state, 'trial')
})
t('mergeFeatureConfig: defaults, sanitising and unknown keys', () => {
  assert.deepEqual(mergeFeatureConfig(null).habits, DEFAULT_FEATURES.habits)
  const m = mergeFeatureConfig({ habits: { trialDays: 9999, enabled: false }, bogus: { enabled: true } })
  assert.equal(m.habits.trialDays, 365); assert.equal(m.habits.enabled, false); assert.equal(m.habits.includedInPremium, true)
  assert.equal(mergeFeatureConfig({ habits: { trialDays: -4 } }).habits.trialDays, 0)
  assert.equal(mergeFeatureConfig({ habits: { trialDays: 'x' } }).habits.trialDays, 14)
  assert.equal('bogus' in m, false)
})
console.log(`\n${n} tests passed`)
