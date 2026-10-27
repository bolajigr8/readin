import { timingSafeEqual } from 'node:crypto'
import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { Types } from 'mongoose'
import { User } from '../models/user.model.js'
import { decide, pickUserId, type RcEvent } from '../services/revenuecat.logic.js'
import { verifyWebhookSignature } from '../services/paystack.service.js'
import { settlePayment } from '../services/payments.service.js'

/** Constant-time comparison (no timing leak of the secret). */
const safeEqual = (a: string, b: string): boolean => {
  const x = Buffer.from(a)
  const y = Buffer.from(b)
  return x.length === y.length && timingSafeEqual(x, y)
}

/**
 * POST /api/v1/webhooks/revenuecat
 * RevenueCat authenticates with the Authorization header you configured in its
 * dashboard (either the bare secret or "Bearer <secret>").
 * Plan changes follow the rules in services/revenuecat.logic.ts.
 */
export const revenueCatWebhook = asyncHandler(async (req: Request, res: Response) => {
  const secret = process.env['REVENUECAT_WEBHOOK_SECRET']
  const header = req.headers.authorization ?? ''

  if (!secret || !(safeEqual(header, secret) || safeEqual(header, `Bearer ${secret}`))) {
    res.status(401).json({ success: false, message: 'Unauthorized.' })
    return
  }

  let event: RcEvent | undefined
  try {
    const raw: unknown = Buffer.isBuffer(req.body) ? JSON.parse(req.body.toString('utf-8')) : req.body
    event = (raw as { event?: RcEvent } | null)?.event
  } catch {
    event = undefined
  }
  if (!event || typeof event !== 'object') {
    // Malformed body — acknowledge so RevenueCat doesn't retry forever.
    console.error('[revenuecat] unreadable webhook body')
    res.status(200).json({ received: true })
    return
  }

  const userId = pickUserId(event, (id) => Types.ObjectId.isValid(id) && /^[a-f0-9]{24}$/i.test(id))
  if (!userId) {
    console.log(`[revenuecat] ${event.type ?? '?'}: no ReadIn user id (${String(event.app_user_id)}) — ignored`)
    res.status(200).json({ received: true })
    return
  }

  const user = await User.findById(userId).select('plan role premiumUntil premiumEventAt')
  if (!user) {
    res.status(200).json({ received: true })
    return
  }

  const decision = decide(event, { premiumUntil: user.premiumUntil ?? null, premiumEventAt: user.premiumEventAt ?? null }, new Date())
  if (decision.action === 'ignore') {
    console.log(`[revenuecat] ${event.type ?? '?'} | ${userId}: ignored (${decision.reason})`)
  } else if (user.role === 'admin') {
    console.log(`[revenuecat] ${event.type ?? '?'} | ${userId}: administrator account left unchanged`)
  } else {
    user.plan = decision.plan
    user.premiumUntil = decision.premiumUntil
    user.premiumEventAt = decision.eventAt
    await user.save()
    console.log(`[revenuecat] ${event.type ?? '?'} | ${userId}: plan → ${decision.plan}`)
  }

  // A database error above throws (500) so RevenueCat retries; everything else is acknowledged.
  res.status(200).json({ received: true })
})

/**
 * POST /api/v1/webhooks/paystack
 * Paystack signs the raw body (x-paystack-signature, HMAC-SHA512). Only a valid
 * signature is accepted; the payment is then re-checked with Paystack itself, so a
 * forged request can never give anyone Premium.
 */
export const paystackWebhook = asyncHandler(async (req: Request, res: Response) => {
  const raw = (req as Request & { rawBody?: Buffer }).rawBody
  const signature = req.headers['x-paystack-signature']
  if (!verifyWebhookSignature(raw, typeof signature === 'string' ? signature : undefined)) {
    res.status(401).json({ success: false, message: 'Invalid signature.' })
    return
  }

  const body = req.body as { event?: string; data?: { reference?: string } } | undefined
  if (body?.event === 'charge.success' && typeof body.data?.reference === 'string') {
    const outcome = await settlePayment(body.data.reference)
    console.log(`[paystack] charge.success ${body.data.reference} → ${outcome.status}`)
    if (outcome.status === 'error') {
      // Paystack unreachable right now: answer 500 so Paystack retries the webhook later.
      res.status(500).json({ received: false })
      return
    }
  }
  res.status(200).json({ received: true })
})
