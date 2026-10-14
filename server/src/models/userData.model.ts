import mongoose, { type Document, Schema, type Types } from 'mongoose'

/**
 * Small per-user JSON documents synced from the phone (habits, shelves…).
 * `version` makes updates safe: a write must say which version it started from.
 */
export interface IUserData extends Document {
  userId: Types.ObjectId
  key: string
  data: string
  version: number
  updatedAt: Date
}

const userDataSchema = new Schema<IUserData>(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    key: { type: String, required: true },
    data: { type: String, required: true },
    version: { type: Number, required: true, default: 1 },
  },
  { timestamps: true },
)

userDataSchema.index({ userId: 1, key: 1 }, { unique: true })

export const UserData = mongoose.model<IUserData>('UserData', userDataSchema)
