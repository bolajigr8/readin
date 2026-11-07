import mongoose, { type Document, Schema } from 'mongoose'
import type { ReleaseChannel } from '../services/appRelease.logic.js'

/** One app version the admin published (S2). Not linked to users. */
export interface IAppRelease extends Document {
  /** direct = APK from the website, play = Google Play. */
  channel: ReleaseChannel
  /** "1.0.1" */
  version: string
  /** Android versionCode (the number after "+" in pubspec). Unique per channel. */
  versionCode: number
  downloadUrl: string
  sha256: string
  sizeBytes: number
  notes: string[]
  /** Everyone older than this release must update. */
  mandatory: boolean
  /** Phones older than this versionCode must update (blocking screen). 0 = none. */
  minSupportedVersionCode: number
  /** Only published releases are offered to phones. */
  published: boolean
  releasedAt: Date | null
  createdAt: Date
  updatedAt: Date
}

const appReleaseSchema = new Schema<IAppRelease>(
  {
    channel: { type: String, enum: ['direct', 'play'], required: true },
    version: { type: String, required: true },
    versionCode: { type: Number, required: true },
    downloadUrl: { type: String, required: true },
    sha256: { type: String, default: '' },
    sizeBytes: { type: Number, default: 0 },
    notes: { type: [String], default: [] },
    mandatory: { type: Boolean, default: false },
    minSupportedVersionCode: { type: Number, default: 0 },
    published: { type: Boolean, default: false },
    releasedAt: { type: Date, default: null },
  },
  { timestamps: true },
)

appReleaseSchema.index({ channel: 1, versionCode: 1 }, { unique: true })

export const AppRelease = mongoose.model<IAppRelease>('AppRelease', appReleaseSchema)
