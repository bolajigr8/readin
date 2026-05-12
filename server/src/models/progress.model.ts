import mongoose, { type Document, Schema, type Types } from 'mongoose'

export interface IProgress extends Document {
  _id: Types.ObjectId
  userId: Types.ObjectId
  bookId: Types.ObjectId
  currentCfi: string
  percentage: number
  currentChapter: number
  currentChapterTitle: string
  totalChapters: number
  lastReadAt: Date
  isCompleted: boolean
  completedAt: Date | null
  readingTimeSeconds: number
  createdAt: Date
  updatedAt: Date
}

const progressSchema = new Schema<IProgress>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    bookId: {
      type: Schema.Types.ObjectId,
      ref: 'Book',
      required: true,
    },
    currentCfi: {
      type: String,
      default: '',
    },
    percentage: {
      type: Number,
      min: 0,
      max: 100,
      default: 0,
    },
    currentChapter: {
      type: Number,
      default: 0,
    },
    currentChapterTitle: {
      type: String,
      default: '',
    },
    totalChapters: {
      type: Number,
      default: 0,
    },
    lastReadAt: {
      type: Date,
      default: () => new Date(),
    },
    isCompleted: {
      type: Boolean,
      default: false,
    },
    completedAt: {
      type: Date,
      default: null,
    },
    readingTimeSeconds: {
      type: Number,
      default: 0,
    },
  },
  { timestamps: true },
)

// One progress record per user per book
progressSchema.index({ userId: 1, bookId: 1 }, { unique: true })

export const Progress = mongoose.model<IProgress>('Progress', progressSchema)
