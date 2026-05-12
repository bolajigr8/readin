import mongoose, { type Document, Schema, type Types } from 'mongoose'

export type BookStatus =
  | 'uploading'
  | 'queued'
  | 'converting'
  | 'ready'
  | 'failed'

export type OriginalFormat = 'pdf' | 'epub' | 'mobi' | 'docx' | 'txt'
export type BookSource = 'upload' | 'discover'

export interface IBook extends Document {
  _id: Types.ObjectId
  userId: Types.ObjectId
  title: string
  author: string
  description: string
  coverUrl: string
  originalFileUrl: string
  originalFilePublicId: string
  convertedFileUrl: string
  convertedFilePublicId: string
  originalFormat: OriginalFormat
  fileSize: number
  pageCount: number
  status: BookStatus
  jobId: string
  isDownloaded: boolean
  source: BookSource
  gutenbergId: string | null
  language: string
  genre: string
  createdAt: Date
  updatedAt: Date
}

const bookSchema = new Schema<IBook>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    author: {
      type: String,
      default: '',
      trim: true,
    },
    description: {
      type: String,
      default: '',
    },
    coverUrl: {
      type: String,
      default: '',
    },
    originalFileUrl: {
      type: String,
      default: '',
    },
    originalFilePublicId: {
      type: String,
      default: '',
    },
    convertedFileUrl: {
      type: String,
      default: '',
    },
    convertedFilePublicId: {
      type: String,
      default: '',
    },
    originalFormat: {
      type: String,
      enum: ['pdf', 'epub', 'mobi', 'docx', 'txt'] satisfies OriginalFormat[],
      required: true,
    },
    fileSize: {
      type: Number,
      default: 0,
    },
    pageCount: {
      type: Number,
      default: 0,
    },
    status: {
      type: String,
      enum: [
        'uploading',
        'queued',
        'converting',
        'ready',
        'failed',
      ] satisfies BookStatus[],
      default: 'uploading',
    },
    jobId: {
      type: String,
      default: '',
    },
    isDownloaded: {
      type: Boolean,
      default: false,
    },
    source: {
      type: String,
      enum: ['upload', 'discover'] satisfies BookSource[],
      default: 'upload',
    },
    gutenbergId: {
      type: String,
      default: null,
    },
    language: {
      type: String,
      default: 'en',
    },
    genre: {
      type: String,
      default: '',
    },
  },
  {
    timestamps: true,
  },
)

// Common query patterns
bookSchema.index({ userId: 1, status: 1 })
bookSchema.index({ userId: 1, source: 1 })

export const Book = mongoose.model<IBook>('Book', bookSchema)
