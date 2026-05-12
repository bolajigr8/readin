import mongoose, { type Document, Schema, type Types } from 'mongoose'

export interface IBookmark extends Document {
  _id: Types.ObjectId
  userId: Types.ObjectId
  bookId: Types.ObjectId
  cfi: string
  label: string
  chapterTitle: string
  chapterIndex: number
  percentage: number
  createdAt: Date
  updatedAt: Date
}

const bookmarkSchema = new Schema<IBookmark>(
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
    cfi: {
      type: String,
      required: true,
    },
    label: {
      type: String,
      default: '',
      maxlength: 200,
    },
    chapterTitle: {
      type: String,
      default: '',
    },
    chapterIndex: {
      type: Number,
      default: 0,
    },
    percentage: {
      type: Number,
      min: 0,
      max: 100,
      default: 0,
    },
  },
  { timestamps: true },
)

bookmarkSchema.index({ bookId: 1, userId: 1 })

export const Bookmark = mongoose.model<IBookmark>('Bookmark', bookmarkSchema)
