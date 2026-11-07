import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { z } from 'zod'
import { User } from '../models/user.model.js'
import { Payment } from '../models/payment.model.js'
import { getBillingConfig } from '../services/billing.service.js'
import { effectivePlan, inAppReminder, publicBilling, trialAvailable } from '../services/billing.logic.js'
import { errorResponse, successResponse } from '../utils/response.utils.js'

const DAY_MS = 86_400_000

/** Everything the app needs for the Premium screen, the reminder banner and the Profile switch. */
const statusFor = async (userId: string) => {
  const [user, cfg, paid] = await Promise.all([
    User.findById(userId).select('plan premiumUntil premiumKind premiumTrialUsedAt emailReminders').lean(),
    getBillingConfig(),
    Payment.exists({ userId, status: 'success' }),
  ])
  if (!user) return null
  const now = new Date()
  const premiumUntil = user.premiumUntil ?? null
  const plan = effectivePlan(user.plan === 'premium' ? 'premium' : 'free', premiumUntil, now)
  const trialUsedAt = user.premiumTrialUsedAt ?? null
  return {
    plan,
    premiumUntil,
    premiumKind: user.premiumKind ?? null,
    emailReminders: user.emailReminders !== false,
    trial: {
      days: cfg.trialDays,
      available: trialAvailable(cfg, { plan: user.plan, premiumUntil, premiumTrialUsedAt: trialUsedAt }, !!paid, now),
      usedAt: trialUsedAt,
    },
    reminder: inAppReminder(premiumUntil, now, publicBilling(cfg).reminders),
  }
}

/** GET /api/v1/billing/status */
export const getStatus = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }
  const status = await statusFor(req.user.userId)
  if (!status) {
    errorResponse(res, 'User not found.', 404)
    return
  }
  successResponse(res, status, 'OK')
})

/** POST /api/v1/billing/trial — starts the one free Premium trial of this account. */
export const startPremiumTrial = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }
  const userId = req.user.userId
  const cfg = await getBillingConfig()
  if (cfg.trialDays <= 0) {
    errorResponse(res, 'A free trial is not available right now.', 400)
    return
  }
  if (await Payment.exists({ userId, status: 'success' })) {
    errorResponse(res, 'The free trial is for new Premium members only.', 409)
    return
  }
  const now = new Date()
  // Atomic: only an account that never had a trial and is not Premium right now can start one.
  const started = await User.findOneAndUpdate(
    {
      _id: userId,
      premiumTrialUsedAt: null,
      $or: [{ plan: 'free' }, { premiumUntil: { $ne: null, $lte: now } }],
    },
    {
      $set: {
        plan: 'premium',
        premiumUntil: new Date(now.getTime() + cfg.trialDays * DAY_MS),
        premiumKind: 'trial',
        premiumTrialUsedAt: now,
        premiumEventAt: now,
      },
    },
    { new: true },
  )
  if (!started) {
    errorResponse(res, 'You have already used your free trial, or Premium is already active.', 409)
    return
  }
  successResponse(res, await statusFor(userId), `Your ${cfg.trialDays}-day free trial has started. Enjoy!`)
})

const remindersSchema = z.object({ email: z.boolean() }).strict()

/** PATCH /api/v1/billing/reminders { email } — the Profile switch "Premium reminder e-mails". */
export const setReminders = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }
  const parsed = remindersSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'Invalid setting.', 400)
    return
  }
  await User.updateOne({ _id: req.user.userId }, { $set: { emailReminders: parsed.data.email } })
  successResponse(
    res,
    { emailReminders: parsed.data.email },
    parsed.data.email ? 'Reminder e-mails are on.' : 'Reminder e-mails are off.',
  )
})
