// Run:  node --experimental-strip-types tests/premium.test.mjs   (Node 22+)
// S9.2 — price hooks, savings, free trial and Premium reminders (pure logic).
import assert from 'node:assert/strict'
import {
  DEFAULT_REMINDERS,
  dueEmailReminder,
  inAppReminder,
  mergeBilling,
  normalizeReminderSteps,
  perDayText,
  planMonths,
  publicBilling,
  reminderKey,
  reminderWindow,
  savingsText,
  trialAvailable,
} from '../src/services/billing.logic.ts'

let n = 0
const t = (name, fn) => { fn(); n++; console.log('ok -', name) }
const DAY = 86_400_000
const monthly = { id: 'monthly', name: 'Monthly', description: '', priceKobo: 70_000, durationDays: 30, active: true, badge: '' }
const yearly = { id: 'yearly', name: 'Yearly', description: '', priceKobo: 700_000, durationDays: 365, active: true, badge: 'Best value' }

// ── hooks ────────────────────────────────────────────────────────────────────
t('₦700 / 30 days → "less than ₦24 a day"', () => assert.equal(perDayText(70_000, 30), 'less than ₦24 a day'))
t('₦7,000 / 365 days → "less than ₦20 a day"', () => assert.equal(perDayText(700_000, 365), 'less than ₦20 a day'))
t('exact whole naira → "just ₦20 a day"', () => assert.equal(perDayText(60_000, 30), 'just ₦20 a day'))
t('plan months: 30→1, 365→12, 90→3, 7→0', () => {
  assert.deepEqual([30, 365, 90, 7].map(planMonths), [1, 12, 3, 0])
})
t('yearly ₦7,000 vs monthly ₦700 → "2 months free · save ₦1,400"', () => {
  assert.equal(savingsText(yearly, [monthly, yearly]), '2 months free · save ₦1,400')
})
t('monthly plan itself has no savings text', () => assert.equal(savingsText(monthly, [monthly, yearly]), ''))
t('no saving (yearly = 12 × monthly) → empty', () => {
  assert.equal(savingsText({ priceKobo: 840_000, durationDays: 365 }, [monthly]), '')
})
t('odd saving → "save ₦X (Y% off)"', () => {
  assert.equal(savingsText({ priceKobo: 750_000, durationDays: 365 }, [monthly]), 'save ₦900 (11% off)')
})
t('only a yearly plan → no comparison', () => assert.equal(savingsText(yearly, [yearly]), ''))

// ── config ───────────────────────────────────────────────────────────────────
t('old saved config (no new fields) → safe defaults', () => {
  const c = mergeBilling({ enabled: true, plans: [monthly], freeLibraryLimit: 10 })
  assert.equal(c.trialDays, 0)
  assert.deepEqual(c.reminders, DEFAULT_REMINDERS)
  assert.deepEqual(c.marketing, { headline: '', showPerDay: true, showSavings: true })
})
t('trialDays clamped to 0…90', () => {
  assert.equal(mergeBilling({ trialDays: 500 }).trialDays, 90)
  assert.equal(mergeBilling({ trialDays: -3 }).trialDays, 0)
})
t('reminder steps: sorted, duplicates removed, clamped, max 6', () => {
  const s = normalizeReminderSteps([
    { offsetDays: 3, inApp: true, email: true }, { offsetDays: -5, inApp: true, email: false },
    { offsetDays: 3, inApp: false, email: false }, { offsetDays: -99, inApp: true, email: true }, { offsetDays: 'x' },
  ])
  assert.deepEqual(s.map((x) => x.offsetDays), [-30, -5, 3])
  assert.equal(s[1].email, false)
  assert.equal(normalizeReminderSteps(Array.from({ length: 10 }, (_, i) => ({ offsetDays: i }))).length, 6)
})
t('public billing: hooks on plans, in-app offsets, trial days, headline', () => {
  const c = mergeBilling({
    enabled: true, plans: [monthly, yearly], trialDays: 7,
    marketing: { headline: 'Read without limits', showPerDay: true, showSavings: true },
    reminders: { enabled: true, steps: [{ offsetDays: -2, inApp: true, email: false }, { offsetDays: 3, inApp: false, email: true }] },
  })
  const p = publicBilling(c)
  assert.equal(p.trialDays, 7); assert.equal(p.headline, 'Read without limits')
  assert.deepEqual(p.reminders, [-2])
  assert.equal(p.plans[0].perDayText, 'less than ₦24 a day')
  assert.equal(p.plans[1].savingsText, '2 months free · save ₦1,400')
})
t('hooks can be switched off in admin', () => {
  const p = publicBilling(mergeBilling({ enabled: true, plans: [monthly, yearly], marketing: { headline: '', showPerDay: false, showSavings: false } }))
  assert.equal(p.plans[0].perDayText, ''); assert.equal(p.plans[1].savingsText, '')
})
t('reminders off → no in-app offsets', () => {
  assert.deepEqual(publicBilling(mergeBilling({ reminders: { enabled: false, steps: DEFAULT_REMINDERS.steps } })).reminders, [])
})

// ── e-mail reminders ─────────────────────────────────────────────────────────
const end = new Date('2026-12-01T12:00:00Z')
const at = (days, hours = 0) => new Date(end.getTime() + days * DAY + hours * 3_600_000)
t('nothing due 6 days before the end', () => assert.equal(dueEmailReminder(end, at(-6), DEFAULT_REMINDERS, []), null))
t('5 days before → the -5 step', () => assert.equal(dueEmailReminder(end, at(-5, 1), DEFAULT_REMINDERS, []).offsetDays, -5))
t('already sent → not again (exactly once)', () => {
  assert.equal(dueEmailReminder(end, at(-5, 1), DEFAULT_REMINDERS, [reminderKey(-5, end)]), null)
})
t('a renewal (new end date) starts fresh', () => {
  const newEnd = new Date(end.getTime() + 30 * DAY)
  assert.equal(dueEmailReminder(newEnd, new Date(newEnd.getTime() - 5 * DAY + 1000), DEFAULT_REMINDERS, [reminderKey(-5, end)]).offsetDays, -5)
})
t('several due at once → only the latest (no flood)', () => {
  const cfg = { enabled: true, steps: [{ offsetDays: -5, inApp: true, email: true }, { offsetDays: -4, inApp: true, email: true }] }
  assert.equal(dueEmailReminder(end, at(-4, 1), cfg, []).offsetDays, -4)
})
t('more than 2 days late → skipped (stale)', () => {
  const cfg = { enabled: true, steps: [{ offsetDays: -5, inApp: true, email: true }] }
  assert.equal(dueEmailReminder(end, at(-2, 1), cfg, []), null)
})
t('the day it ends and 3 days after', () => {
  assert.equal(dueEmailReminder(end, at(0, 1), DEFAULT_REMINDERS, []).offsetDays, 0)
  assert.equal(dueEmailReminder(end, at(3, 2), DEFAULT_REMINDERS, []).offsetDays, 3)
})
t('e-mail switched off on a step / reminders off / no end date → nothing', () => {
  const cfg = { enabled: true, steps: [{ offsetDays: -5, inApp: true, email: false }] }
  assert.equal(dueEmailReminder(end, at(-5, 1), cfg, []), null)
  assert.equal(dueEmailReminder(end, at(-5, 1), { ...DEFAULT_REMINDERS, enabled: false }, []), null)
  assert.equal(dueEmailReminder(null, at(-5, 1), DEFAULT_REMINDERS, []), null)
})
t('database window covers every due step', () => {
  const now = at(-5, 1)
  const w = reminderWindow(DEFAULT_REMINDERS, now)
  assert.ok(end >= w.from && end <= w.to)
  const later = at(3, 1)
  const w2 = reminderWindow(DEFAULT_REMINDERS, later)
  assert.ok(end >= w2.from && end <= w2.to)
  assert.equal(reminderWindow({ enabled: false, steps: DEFAULT_REMINDERS.steps }, now), null)
})

// ── in-app banner ────────────────────────────────────────────────────────────
const offs = [-5, -2, 0, 3]
t('banner: none before the first step', () => assert.equal(inAppReminder(end, at(-6), offs), null))
t('banner: 5 days left', () => assert.deepEqual(inAppReminder(end, at(-5), offs), { kind: 'before', daysLeft: 5, premiumUntil: end.toISOString() }))
t('banner: last hours → "today"', () => assert.equal(inAppReminder(end, at(0, -3), offs).kind, 'today'))
t('banner: 3 days after → "after"', () => assert.deepEqual(inAppReminder(end, at(3, 1), offs), { kind: 'after', daysAgo: 3, premiumUntil: end.toISOString() }))
t('banner: gone 7 days after the last step', () => assert.equal(inAppReminder(end, at(11), offs), null))
t('banner: no steps / no end date → none', () => {
  assert.equal(inAppReminder(end, at(-1), []), null); assert.equal(inAppReminder(null, at(-1), offs), null)
})

// ── trial ────────────────────────────────────────────────────────────────────
const now = new Date('2026-11-07T10:00:00Z')
const free = { plan: 'free', premiumUntil: null, premiumTrialUsedAt: null }
t('trial available for a new free account', () => assert.equal(trialAvailable({ trialDays: 7 }, free, false, now), true))
t('trial: off when trialDays = 0', () => assert.equal(trialAvailable({ trialDays: 0 }, free, false, now), false))
t('trial: only once', () => assert.equal(trialAvailable({ trialDays: 7 }, { ...free, premiumTrialUsedAt: now }, false, now), false))
t('trial: not for people who already paid', () => assert.equal(trialAvailable({ trialDays: 7 }, free, true, now), false))
t('trial: not while Premium is active; yes after it expired', () => {
  assert.equal(trialAvailable({ trialDays: 7 }, { ...free, plan: 'premium', premiumUntil: new Date(now.getTime() + DAY) }, false, now), false)
  assert.equal(trialAvailable({ trialDays: 7 }, { ...free, plan: 'premium', premiumUntil: new Date(now.getTime() - DAY) }, false, now), true)
})

console.log(`\n${n} tests passed`)
