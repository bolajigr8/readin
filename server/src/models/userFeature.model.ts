import mongoose, { type Document, Schema, type Types } from 'mongoose'

/** Per-user state of a premium/trial feature (trial start, admin grant/revoke). */
export interface IUserFeature extends Document {
  userId: Types.ObjectId
  key: string
  trialStartedAt: Date | null
  grantedUntil: Date | null
  revoked: boolean
}

const userFeatureSchema = new Schema<IUserFeature>(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    key: { type: String, required: true },
    trialStartedAt: { type: Date, default: null },
    grantedUntil: { type: Date, default: null },
    revoked: { type: Boolean, default: false },
  },
  { timestamps: true },
)

userFeatureSchema.index({ userId: 1, key: 1 }, { unique: true })

export const UserFeature = mongoose.model<IUserFeature>('UserFeature', userFeatureSchema)
