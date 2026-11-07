import { User } from '../models/user.model.js'
import { getBillingConfig } from './billing.service.js'
import {
  dueEmailReminder,
  formatNaira,
  perDayText,
  planMonths,
  reminderKey,
  reminderWindow,
  type BillingConfig,
} from './billing.logic.js'
import { emailService } from './email/email.service.js'

/** "Premium is ₦700 a month — less than ₦24 a day." from the cheapest active monthly plan ('' if none / payments off). */
export const offerLine = (cfg: BillingConfig): string => {
  if (!cfg.enabled) return ''
  const monthly = cfg.plans
    .filter((p) => p.active && planMonths(p.durationDays) === 1)
    .sort((a, b) => a.priceKobo - b.priceKobo)[0]
  if (!monthly) return ''
  return `Premium is ${formatNaira(monthly.priceKobo)} a month — ${perDayText(monthly.priceKobo, monthly.durationDays)}.`
}

const BATCH = 500

/**
 * Sends every reminder e-mail that is due right now — each one at most once (atomic claim on the user's
 * `premiumRemindersSent` list before sending). Safe to run as often as you like.
 */
export const runPremiumReminders = async (now = new Date()): Promise<{ checked: number; sent: number }> => {
  const cfg = await getBillingConfig()
  const window = reminderWindow(cfg.reminders, now)
  if (!window) return { checked: 0, sent: 0 }

  const users = await User.find({
    premiumUntil: { $gte: window.from, $lte: window.to },
    emailReminders: { $ne: false },
    disabled: { $ne: true },
    isEmailVerified: true,
    role: 'user',
  })
    .select('email displayName premiumUntil premiumKind premiumRemindersSent')
    .limit(BATCH)
    .lean()

  const offer = offerLine(cfg)
  let sent = 0
  for (const u of users) {
    if (!u.premiumUntil) continue
    const step = dueEmailReminder(u.premiumUntil, now, cfg.reminders, u.premiumRemindersSent ?? [])
    if (!step) continue
    const key = reminderKey(step.offsetDays, u.premiumUntil)
    // Claim first: only one server run can add the key, so the e-mail goes out exactly once.
    const claim = await User.updateOne(
      { _id: u._id, premiumUntil: u.premiumUntil, premiumRemindersSent: { $ne: key } },
      { $push: { premiumRemindersSent: { $each: [key], $slice: -20 } } },
    )
    if (claim.modifiedCount !== 1) continue
    try {
      await emailService.sendPremiumReminderEmail({
        to: u.email,
        name: u.displayName,
        offsetDays: step.offsetDays,
        kind: u.premiumKind ?? null,
        premiumUntil: u.premiumUntil,
        offer,
      })
      sent++
    } catch (err) {
      // Not retried (better one missed reminder than a flood). No address in the log.
      console.error('[reminders] e-mail failed:', err instanceof Error ? err.message : err)
    }
  }
  if (sent > 0) console.log(`[reminders] sent ${sent} Premium reminder e-mail(s)`)
  return { checked: users.length, sent }
}

let timer: NodeJS.Timeout | null = null

/**
 * Runs the reminder check every hour (env PREMIUM_REMINDERS_INTERVAL_MS; 0 = off). The cron-job.org
 * health pings keep the free Render server awake, so the check really runs.
 */
export const startPremiumReminderScheduler = (): void => {
  const every = Number(process.env['PREMIUM_REMINDERS_INTERVAL_MS'] ?? '3600000')
  if (!Number.isFinite(every) || every <= 0 || timer) return
  const run = (): void => {
    runPremiumReminders().catch((err: unknown) =>
      console.error('[reminders] check failed:', err instanceof Error ? err.message : err),
    )
  }
  setTimeout(run, Math.min(60_000, every)).unref()
  timer = setInterval(run, Math.max(60_000, every))
  timer.unref()
}
