import mongoose, { type Document, Schema, type Types } from 'mongoose'

export interface IUser extends Document {
  _id: Types.ObjectId
  email: string
  passwordHash: string | null
  googleId: string | null
  displayName: string
  avatar: string
  plan: 'free' | 'premium'
  /**
   * S5: owner / admin = the team (set on the admin Team page by an owner, or by a script), tester = testing
   * helper (Premium-equivalent, no admin panel), user = everyone else. See services/roles.logic.ts.
   */
  role: 'user' | 'tester' | 'admin' | 'owner'
  /** Admin-panel permissions of an `admin` (owners have all). */
  permissions: string[]
  roleChangedAt: Date | null
  roleChangedBy: Types.ObjectId | null
  /** An administrator can switch an account off (cannot log in or refresh). */
  disabled: boolean
  lastLoginAt: Date | null
  /** When the paid period ends (from RevenueCat); informational for the admin panel. */
  premiumUntil: Date | null
  /** Timestamp of the last RevenueCat event applied (ignores late, out-of-order events). */
  premiumEventAt: Date | null
  /** How the current Premium period came about (wording of reminders): paid | trial | gift. */
  premiumKind: 'paid' | 'trial' | 'gift' | null
  /** When the one free Premium trial was started (null = never). */
  premiumTrialUsedAt: Date | null
  /** Reminder e-mails already sent, as `offset@premiumUntilISO` keys (exactly once each). */
  premiumRemindersSent: string[]
  /** The user may switch off Premium reminder e-mails (Profile). */
  emailReminders: boolean
  isEmailVerified: boolean
  emailVerificationToken: string | null
  emailVerificationExpires: Date | null
  passwordResetToken: string | null
  passwordResetExpires: Date | null
  /** Web "delete my account" link (S7.1): SHA-256 of the token from the e-mail, and when it expires. */
  accountDeletionTokenHash: string | null
  accountDeletionExpires: Date | null
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
      enum: ['user', 'tester', 'admin', 'owner'],
      default: 'user',
    },
    permissions: {
      type: [String],
      default: [],
    },
    roleChangedAt: {
      type: Date,
      default: null,
    },
    roleChangedBy: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      default: null,
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
    premiumKind: {
      type: String,
      enum: ['paid', 'trial', 'gift', null],
      default: null,
    },
    premiumTrialUsedAt: {
      type: Date,
      default: null,
    },
    premiumRemindersSent: {
      type: [String],
      default: [],
    },
    emailReminders: {
      type: Boolean,
      default: true,
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
    accountDeletionTokenHash: {
      type: String,
      default: null,
    },
    accountDeletionExpires: {
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
userSchema.index({ accountDeletionTokenHash: 1 }, { sparse: true })

export const User = mongoose.model<IUser>('User', userSchema)
