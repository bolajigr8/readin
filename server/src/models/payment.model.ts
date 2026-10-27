import mongoose, { type Document, Schema, type Types } from 'mongoose'

/** One Paystack payment attempt. Amounts are kobo (₦1 = 100 kobo). */
export interface IPayment extends Document {
  userId: Types.ObjectId
  email: string
  planId: string
  planName: string
  /** Paystack reference — unique, created by us. */
  reference: string
  amountKobo: number
  currency: string
  durationDays: number
  status: 'pending' | 'success' | 'failed' | 'abandoned'
  /** The Premium period was added to the user (guards against double credit). */
  applied: boolean
  paystackId: number | null
  channel: string
  paidAt: Date | null
  premiumUntil: Date | null
  failureReason: string
  createdAt: Date
  updatedAt: Date
}

const paymentSchema = new Schema<IPayment>(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    email: { type: String, required: true },
    planId: { type: String, required: true },
    planName: { type: String, required: true },
    reference: { type: String, required: true, unique: true },
    amountKobo: { type: Number, required: true },
    currency: { type: String, default: 'NGN' },
    durationDays: { type: Number, required: true },
    status: { type: String, enum: ['pending', 'success', 'failed', 'abandoned'], default: 'pending' },
    applied: { type: Boolean, default: false },
    paystackId: { type: Number, default: null },
    channel: { type: String, default: '' },
    paidAt: { type: Date, default: null },
    premiumUntil: { type: Date, default: null },
    failureReason: { type: String, default: '' },
  },
  { timestamps: true },
)

paymentSchema.index({ createdAt: -1 })

export const Payment = mongoose.model<IPayment>('Payment', paymentSchema)
