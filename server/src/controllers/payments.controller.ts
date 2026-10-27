import { randomBytes } from 'node:crypto'
import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { z } from 'zod'
import { Payment } from '../models/payment.model.js'
import { User } from '../models/user.model.js'
import { getBillingConfig } from '../services/billing.service.js'
import { formatNaira } from '../services/billing.logic.js'
import { initializeTransaction, paystackConfigured, publicBaseUrl } from '../services/paystack.service.js'
import { settlePayment } from '../services/payments.service.js'
import { errorResponse, successResponse } from '../utils/response.utils.js'

const checkoutSchema = z.object({ planId: z.string().min(1).max(60) })

/**
 * POST /api/v1/payments/checkout  { planId }
 * The PRICE always comes from the server's plan list — never from the phone.
 * Returns the Paystack page to open; the phone then calls /payments/verify/:reference.
 */
export const checkout = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }
  const parsed = checkoutSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'Choose a plan.', 400)
    return
  }
  const billing = await getBillingConfig()
  if (!billing.enabled) {
    errorResponse(res, 'Payments are not available right now.', 403)
    return
  }
  if (!paystackConfigured()) {
    console.error('[payments] PAYSTACK_SECRET_KEY is missing or invalid')
    errorResponse(res, 'Payments are not set up yet. Please try again later.', 503)
    return
  }
  const plan = billing.plans.find((p) => p.id === parsed.data.planId && p.active)
  if (!plan) {
    errorResponse(res, 'That plan is no longer available.', 404)
    return
  }
  const user = await User.findById(req.user.userId).select('email displayName')
  if (!user) {
    errorResponse(res, 'Account not found.', 404)
    return
  }

  const reference = `rdn_${randomBytes(10).toString('hex')}`
  const init = await initializeTransaction({
    email: user.email,
    amountKobo: plan.priceKobo,
    reference,
    callbackUrl: `${publicBaseUrl()}/payment/callback`,
    metadata: { userId: String(user._id), planId: plan.id, planName: plan.name },
  })
  if (!init.ok || !init.data) {
    console.error('[payments] initialize failed:', init.status, init.message)
    errorResponse(res, 'Could not start the payment. Please try again.', 502)
    return
  }

  await Payment.create({
    userId: user._id,
    email: user.email,
    planId: plan.id,
    planName: plan.name,
    reference,
    amountKobo: plan.priceKobo,
    currency: 'NGN',
    durationDays: plan.durationDays,
    status: 'pending',
  })

  successResponse(res, {
    authorizationUrl: init.data.authorization_url,
    reference,
    amountKobo: plan.priceKobo,
    amountText: formatNaira(plan.priceKobo),
    planName: plan.name,
  })
})

/**
 * GET /api/v1/payments/verify/:reference
 * Asks Paystack about the payment and (if paid) activates Premium. Safe to repeat.
 */
export const verify = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }
  const reference = String(req.params['reference'] ?? '')
  const mine = await Payment.findOne({ reference, userId: req.user.userId }).select('_id')
  if (!mine) {
    errorResponse(res, 'Payment not found.', 404)
    return
  }
  const outcome = await settlePayment(reference)
  const user = await User.findById(req.user.userId).select('plan premiumUntil')
  const base = { plan: user?.plan ?? 'free', premiumUntil: user?.premiumUntil ?? null }

  switch (outcome.status) {
    case 'success':
      successResponse(res, { status: 'success', ...base }, 'Payment successful. Premium is active.')
      return
    case 'pending':
      successResponse(res, { status: 'pending', ...base }, 'Payment is still processing.')
      return
    case 'failed':
      successResponse(res, { status: 'failed', reason: outcome.reason, ...base }, 'Payment was not completed.')
      return
    case 'error':
      errorResponse(res, 'Could not check the payment right now. It will activate automatically if it went through.', 502)
      return
    default:
      errorResponse(res, 'Payment not found.', 404)
  }
})

/** GET /api/v1/payments/history — the signed-in user's last 20 payments. */
export const history = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }
  const rows = await Payment.find({ userId: req.user.userId }).sort({ createdAt: -1 }).limit(20).lean()
  successResponse(res, {
    items: rows.map((p) => ({
      reference: p.reference,
      planName: p.planName,
      amountKobo: p.amountKobo,
      amountText: formatNaira(p.amountKobo),
      status: p.status,
      paidAt: p.paidAt,
      premiumUntil: p.premiumUntil,
      createdAt: p.createdAt,
    })),
  })
})
