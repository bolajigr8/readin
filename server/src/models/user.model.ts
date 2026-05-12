import mongoose, { type Document, Schema, type Types } from 'mongoose'

export interface IUser extends Document {
  _id: Types.ObjectId
  email: string
  passwordHash: string | null
  googleId: string | null
  displayName: string
  avatar: string
  plan: 'free' | 'premium'
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
