import mongoose, { type Document, Schema, type Types } from 'mongoose'

export type AnnotationType = 'highlight' | 'note'
export type AnnotationColor = 'yellow' | 'green' | 'blue' | 'pink' | 'purple'

export interface IAnnotation extends Document {
  _id: Types.ObjectId
  userId: Types.ObjectId
  bookId: Types.ObjectId
  type: AnnotationType
  cfiRange: string
  selectedText: string
  note: string
  color: AnnotationColor
  chapterTitle: string
  chapterIndex: number
  createdAt: Date
  updatedAt: Date
}

const annotationSchema = new Schema<IAnnotation>(
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
    type: {
      type: String,
      enum: ['highlight', 'note'] satisfies AnnotationType[],
      required: true,
    },
    cfiRange: {
      type: String,
      required: true,
    },
    selectedText: {
      type: String,
      required: true,
      maxlength: 2000,
    },
    note: {
      type: String,
      default: '',
      maxlength: 5000,
    },
    color: {
      type: String,
      enum: [
        'yellow',
        'green',
        'blue',
        'pink',
        'purple',
      ] satisfies AnnotationColor[],
      default: 'yellow',
    },
    chapterTitle: {
      type: String,
      default: '',
    },
    chapterIndex: {
      type: Number,
      default: 0,
    },
  },
  { timestamps: true },
)

annotationSchema.index({ bookId: 1, userId: 1 })

export const Annotation = mongoose.model<IAnnotation>(
  'Annotation',
  annotationSchema,
)
