import mongoose, { type Document, Schema, type Types } from 'mongoose'

export type JobStatus = 'waiting' | 'active' | 'completed' | 'failed'

export interface IJob extends Document {
  _id: Types.ObjectId
  jobId: string
  userId: Types.ObjectId
  bookId: Types.ObjectId
  status: JobStatus
  progress: number
  error: string | null
  startedAt: Date | null
  completedAt: Date | null
  createdAt: Date
  updatedAt: Date
}

const jobSchema = new Schema<IJob>(
  {
    jobId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    bookId: {
      type: Schema.Types.ObjectId,
      ref: 'Book',
      required: true,
    },
    status: {
      type: String,
      enum: ['waiting', 'active', 'completed', 'failed'] satisfies JobStatus[],
      default: 'waiting',
    },
    progress: {
      type: Number,
      min: 0,
      max: 100,
      default: 0,
    },
    error: {
      type: String,
      default: null,
    },
    startedAt: {
      type: Date,
      default: null,
    },
    completedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  },
)

export const Job = mongoose.model<IJob>('Job', jobSchema)
