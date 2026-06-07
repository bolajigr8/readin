import mongoose, { type Document, Schema, type Types } from 'mongoose';

export type JobStatus = 'waiting' | 'active' | 'completed' | 'failed';
export type OriginalFormat = 'pdf' | 'epub' | 'mobi' | 'docx' | 'txt';

export interface IJob extends Document {
  _id: Types.ObjectId;
  jobId: string;
  userId: Types.ObjectId;
  bookId: Types.ObjectId;
  status: JobStatus;
  progress: number;
  error: string | null;
  startedAt: Date | null;
  completedAt: Date | null;
  originalFilename: string;
  originalFormat: OriginalFormat;
  originalFileUrl: string;
  createdAt: Date;
  updatedAt: Date;
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
    originalFilename: {
      type: String,
      required: true,
    },
    originalFormat: {
      type: String,
      enum: ['pdf', 'epub', 'mobi', 'docx', 'txt'] satisfies OriginalFormat[],
      required: true,
    },
    originalFileUrl: {
      type: String,
      required: true,
    },
  },
  {
    timestamps: true,
  },
);

export const Job = mongoose.model<IJob>('Job', jobSchema);
