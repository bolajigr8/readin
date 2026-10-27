import { Payment, type IPayment } from '../models/payment.model.js'
import { User } from '../models/user.model.js'
import { computePremiumUntil } from './billing.logic.js'
import { verifyTransaction } from './paystack.service.js'
import { emailService } from './email/email.service.js'

export type PaymentOutcome =
  | { status: 'success'; payment: IPayment; premiumUntil: Date | null }
  | { status: 'pending'; payment: IPayment }
  | { status: 'failed'; payment: IPayment; reason: string }
  | { status: 'unknown' }
  | { status: 'error'; message: string }

/**
 * Settles a payment by asking PAYSTACK (never trusting the browser or the
 * request body): the amount and currency must match what we asked for. Safe to
 * call any number of times and from several places at once (return page, app,
 * webhook) — the Premium period is added exactly once.
 */
export const settlePayment = async (reference: string): Promise<PaymentOutcome> => {
  let payment = await Payment.findOne({ reference })
  if (!payment) return { status: 'unknown' }

  if (payment.status !== 'success') {
    const v = await verifyTransaction(reference)
    if (!v.ok || !v.data) {
      return payment.status === 'pending'
        ? { status: 'error', message: v.message }
        : { status: 'failed', payment, reason: payment.failureReason || payment.status }
    }
    const d = v.data
    if (d.status === 'success') {
      if (d.amount !== payment.amountKobo || d.currency !== payment.currency) {
        console.error(`[payments] amount mismatch for ${reference}: paid ${d.amount} ${d.currency}, expected ${payment.amountKobo} ${payment.currency}`)
        await Payment.updateOne(
          { _id: payment._id, status: { $ne: 'success' } },
          { $set: { status: 'failed', failureReason: 'Amount did not match the plan price.' } },
        )
        payment = (await Payment.findById(payment._id)) ?? payment
        return { status: 'failed', payment, reason: 'amount mismatch' }
      }
      await Payment.updateOne(
        { _id: payment._id, status: { $ne: 'success' } },
        {
          $set: {
            status: 'success',
            paystackId: d.id,
            channel: d.channel ?? '',
            paidAt: d.paid_at ? new Date(d.paid_at) : new Date(),
          },
        },
      )
    } else if (d.status === 'failed' || d.status === 'abandoned' || d.status === 'reversed') {
      await Payment.updateOne(
        { _id: payment._id, status: 'pending' },
        { $set: { status: d.status === 'abandoned' ? 'abandoned' : 'failed', failureReason: d.gateway_response ?? d.status } },
      )
      payment = (await Payment.findById(payment._id)) ?? payment
      return { status: 'failed', payment, reason: d.gateway_response ?? d.status }
    } else {
      return { status: 'pending', payment } // ongoing / pending / queued
    }
  }

  // Paid. Add the Premium period exactly once (atomic claim on `applied`).
  const claimed = await Payment.findOneAndUpdate(
    { _id: payment._id, status: 'success', applied: false },
    { $set: { applied: true } },
    { returnDocument: 'after' },
  )
  if (claimed) {
    try {
      const user = await User.findById(claimed.userId)
      if (!user) throw new Error('user not found')
      const now = new Date()
      // New time is added AFTER any paid time still left (an expired or missing end date starts now).
      const until = computePremiumUntil(user.plan === 'premium' ? (user.premiumUntil ?? null) : null, now, claimed.durationDays)
      user.plan = 'premium'
      user.premiumUntil = until
      user.premiumEventAt = now
      await user.save()
      await Payment.updateOne({ _id: claimed._id }, { $set: { premiumUntil: until } })

      emailService
        .sendPaymentReceiptEmail({
          to: user.email,
          name: user.displayName,
          planName: claimed.planName,
          amountKobo: claimed.amountKobo,
          reference: claimed.reference,
          paidAt: claimed.paidAt ?? now,
          premiumUntil: until,
        })
        .catch((err: unknown) => console.error('[email] receipt failed:', err))
    } catch (err) {
      // Give the claim back so the next attempt (webhook retry / app) can finish the job.
      await Payment.updateOne({ _id: claimed._id }, { $set: { applied: false } })
      throw err
    }
  }

  const fresh = (await Payment.findById(payment._id)) ?? payment
  return { status: 'success', payment: fresh, premiumUntil: fresh.premiumUntil }
}
