import mongoose, { type Document, Schema } from 'mongoose'

/** Remote settings the administrator changes without touching the code. */
export interface IAppConfig extends Document {
  key: string
  /** features.<featureKey> = { enabled, trialDays, includedInPremium } */
  features: Record<string, { enabled?: boolean; trialDays?: number; includedInPremium?: boolean }>
  updatedBy: string | null
  updatedAt: Date
}

const appConfigSchema = new Schema<IAppConfig>(
  {
    key: { type: String, required: true, unique: true },
    features: { type: Schema.Types.Mixed, default: {} },
    updatedBy: { type: String, default: null },
  },
  { timestamps: true },
)

export const AppConfig = mongoose.model<IAppConfig>('AppConfig', appConfigSchema)
