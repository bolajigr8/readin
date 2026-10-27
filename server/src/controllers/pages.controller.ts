import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { isResetTokenValid, verifyEmailByToken } from './auth.controller.js'
import { Payment } from '../models/payment.model.js'
import { formatNaira } from '../services/billing.logic.js'
import { settlePayment } from '../services/payments.service.js'
import {
  landingPage,
  notFoundPage,
  paymentResultPage,
  resetInvalidPage,
  resetPasswordPage,
  verifyEmailPage,
} from '../services/pages/pages.js'

const q = (v: unknown): string => (typeof v === 'string' ? v : '')

const send = (res: Response, status: number, html: string): void => {
  res.status(status).set('Cache-Control', 'no-store').type('html').send(html)
}

/** GET / */
export const landing = (_req: Request, res: Response): void => send(res, 200, landingPage())

/** GET /verify-email?token=… (the link in the e-mail) */
export const verifyEmailPageHandler = asyncHandler(async (req: Request, res: Response) => {
  const outcome = await verifyEmailByToken(q(req.query['token']))
  send(res, outcome === 'ok' || outcome === 'already' ? 200 : 400, verifyEmailPage(outcome))
})

/** GET /reset-password?token=… (the link in the e-mail): the "choose a new password" form */
export const resetPasswordPageHandler = asyncHandler(async (req: Request, res: Response) => {
  const token = q(req.query['token'])
  if (!(await isResetTokenValid(token))) {
    send(res, 400, resetInvalidPage())
    return
  }
  send(res, 200, resetPasswordPage(token))
})

/**
 * GET /payment/callback?reference=…  — where Paystack sends the customer after
 * paying. The result is confirmed with Paystack (not taken from the URL).
 */
export const paymentCallback = asyncHandler(async (req: Request, res: Response) => {
  const reference = q(req.query['reference']) || q(req.query['trxref'])
  if (!reference) {
    send(res, 400, paymentResultPage({ status: 'unknown' }))
    return
  }
  const outcome = await settlePayment(reference)
  if (outcome.status === 'success') {
    const p = outcome.payment
    send(
      res,
      200,
      paymentResultPage({
        status: 'success',
        planName: p.planName,
        amountText: formatNaira(p.amountKobo),
        reference: p.reference,
        premiumUntilText: (outcome.premiumUntil ?? new Date()).toLocaleDateString('en-GB', {
          day: 'numeric',
          month: 'long',
          year: 'numeric',
          timeZone: 'Africa/Lagos',
        }),
      }),
    )
    return
  }
  if (outcome.status === 'pending') {
    send(res, 200, paymentResultPage({ status: 'pending', reference }))
    return
  }
  if (outcome.status === 'failed') {
    send(res, 200, paymentResultPage({ status: 'failed', reason: outcome.reason, reference }))
    return
  }
  const exists = await Payment.exists({ reference })
  send(res, exists ? 502 : 404, paymentResultPage({ status: exists ? 'error' : 'unknown', reference }))
})

export const notFoundHtml = (_req: Request, res: Response): void => send(res, 404, notFoundPage())
