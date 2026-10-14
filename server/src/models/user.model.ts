import mongoose, { type Document, Schema, type Types } from 'mongoose'

export interface IUser extends Document {
  _id: Types.ObjectId
  email: string
  passwordHash: string | null
  googleId: string | null
  displayName: string
  avatar: string
  plan: 'free' | 'premium'
  /** 'admin' is set ONLY by the create-admin script, never through the API. */
  role: 'user' | 'admin'
  /** An administrator can switch an account off (cannot log in or refresh). */
  disabled: boolean
  lastLoginAt: Date | null
  /** When the paid period ends (from RevenueCat); informational for the admin panel. */
  premiumUntil: Date | null
  /** Timestamp of the last RevenueCat event applied (ignores late, out-of-order events). */
  premiumEventAt: Date | null
  isEmailVerified: boolean
  emailVerificationToken: string | null
  emailVerificationExpires: Date | null
  passwordResetToken: string | null
  passwordResetExpires: Date | null
  expoPushToken: string | null
  refreshTokens: string[]
  createdAt: Date
  updatedAt: Date
}

const userSchema = new Schema<IUser>(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    passwordHash: {
      type: String,
      default: null,
    },
    googleId: {
      type: String,
      default: null,
      sparse: true, // allows multiple null values in unique-ish index
    },
    displayName: {
      type: String,
      required: true,
      trim: true,
    },
    avatar: {
      type: String,
      default: '',
    },
    plan: {
      type: String,
      enum: ['free', 'premium'],
      default: 'free',
    },
    role: {
      type: String,
      enum: ['user', 'admin'],
      default: 'user',
    },
    disabled: {
      type: Boolean,
      default: false,
    },
    lastLoginAt: {
      type: Date,
      default: null,
    },
    premiumUntil: {
      type: Date,
      default: null,
    },
    premiumEventAt: {
      type: Date,
      default: null,
    },
    isEmailVerified: {
      type: Boolean,
      default: false,
    },
    emailVerificationToken: {
      type: String,
      default: null,
    },
    emailVerificationExpires: {
      type: Date,
      default: null,
    },
    passwordResetToken: {
      type: String,
      default: null,
    },
    passwordResetExpires: {
      type: Date,
      default: null,
    },
    expoPushToken: {
      type: String,
      default: null,
    },
    refreshTokens: {
      type: [String],
      default: [],
    },
  },
  {
    timestamps: true,
  },
)

// Index for faster token lookups
userSchema.index({ emailVerificationToken: 1 })
userSchema.index({ passwordResetToken: 1 })

export const User = mongoose.model<IUser>('User', userSchema)
