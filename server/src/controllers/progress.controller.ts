import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { z } from 'zod'
import mongoose from 'mongoose'

import { Progress } from '../models/progress.model.js'
import { Book } from '../models/book.model.js'
import { Annotation } from '../models/annotation.model.js'
import { successResponse, errorResponse } from '../utils/response.utils.js'

const saveProgressSchema = z.object({
  currentCfi: z.string().default(''),
  percentage: z.number().min(0).max(100),
  currentChapter: z.number().int().min(0).default(0),
  currentChapterTitle: z.string().default(''),
  totalChapters: z.number().int().min(0).default(0),
  readingTimeDeltaSeconds: z.number().int().min(0).default(0),
})

// ── saveProgress ──────────────────────────────────────────────────────────────

export const saveProgress = asyncHandler(
  async (req: Request, res: Response) => {
    if (!req.user) {
      errorResponse(res, 'Not authenticated.', 401)
      return
    }

    const bookId = req.params['bookId']
    if (!bookId || !mongoose.isValidObjectId(bookId)) {
      errorResponse(res, 'Invalid bookId.', 400)
      return
    }

    const parsed = saveProgressSchema.safeParse(req.body)
    if (!parsed.success) {
      errorResponse(
        res,
        'Validation failed',
        400,
        parsed.error.flatten().fieldErrors,
      )
      return
    }

    const {
      currentCfi,
      percentage,
      currentChapter,
      currentChapterTitle,
      totalChapters,
      readingTimeDeltaSeconds,
    } = parsed.data

    const isCompleted = percentage >= 99

    // Bug fix 1: use $set for direct fields + $inc together.
    // MongoDB does not allow mixing plain field assignments with update operators.
    const setFields: Record<string, unknown> = {
      currentCfi,
      percentage,
      currentChapter,
      currentChapterTitle,
      totalChapters,
      lastReadAt: new Date(),
      isCompleted,
    }

    // Only write completedAt when the book is actually finished
    if (isCompleted) {
      setFields['completedAt'] = new Date()
    }

    const progress = await Progress.findOneAndUpdate(
      { userId: req.user.userId, bookId },
      {
        $set: setFields,
        $inc: { readingTimeSeconds: readingTimeDeltaSeconds },
      },
      { upsert: true, new: true, setDefaultsOnInsert: true },
    )

    successResponse(res, { progress }, 'Progress saved.')
  },
)

// ── getProgress ───────────────────────────────────────────────────────────────

export const getProgress = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }

  const bookId = req.params['bookId']
  if (!bookId || !mongoose.isValidObjectId(bookId)) {
    errorResponse(res, 'Invalid bookId.', 400)
    return
  }

  const progress = await Progress.findOne({
    bookId,
    userId: req.user.userId,
  }).lean()

  // null is valid — means the user hasn't started this book yet
  successResponse(res, { progress })
})

// ── getReadingStats ───────────────────────────────────────────────────────────

export const getReadingStats = asyncHandler(
  async (req: Request, res: Response) => {
    if (!req.user) {
      errorResponse(res, 'Not authenticated.', 401)
      return
    }

    const { userId } = req.user

    const [totalBooks, annotationCount, booksCompleted, booksInProgress, allProgress] = await Promise.all([
      Book.countDocuments({ userId, status: 'ready' }),
      Annotation.countDocuments({ userId }),
      Progress.countDocuments({ userId, isCompleted: true }),
      Progress.countDocuments({
        userId,
        percentage: { $gt: 0, $lt: 99 },
        isCompleted: false,
      }),
      Progress.find({ userId })
        .select('lastReadAt')
        .sort({ lastReadAt: -1 })
        .lean(),
    ])

    // Sum total reading time across all books
    const timeResult = await Progress.aggregate<{ total: number }>([
      { $match: { userId: new mongoose.Types.ObjectId(userId) } },
      { $group: { _id: null, total: { $sum: '$readingTimeSeconds' } } },
    ])

    const totalReadingTimeSeconds = timeResult[0]?.total ?? 0

    const currentStreak = calculateStreak(allProgress.map((p) => p.lastReadAt))

    // The mobile Profile screen reads totalBooks / completedBooks /
    // averageCompletionRate / annotationCount. The original keys are kept so
    // nothing else breaks.
    const avgAgg = await Progress.aggregate<{ avg: number }>([
      { $match: { userId: new mongoose.Types.ObjectId(userId) } },
      { $group: { _id: null, avg: { $avg: '$percentage' } } },
    ])

    successResponse(res, {
      totalBooks,
      completedBooks: booksCompleted,
      averageCompletionRate: Math.round(avgAgg[0]?.avg ?? 0),
      annotationCount,
      booksCompleted,
      booksInProgress,
      totalReadingTimeSeconds,
      currentStreak,
    })
  },
)

// ── Streak helper ─────────────────────────────────────────────────────────────

const toDateString = (date: Date): string => date.toISOString().slice(0, 10) // "YYYY-MM-DD"

const calculateStreak = (dates: Date[]): number => {
  if (dates.length === 0) return 0

  // Unique days, sorted descending (most recent first)
  const uniqueDays = [...new Set(dates.map(toDateString))].sort((a, b) =>
    b.localeCompare(a),
  )

  const today = toDateString(new Date())
  const yesterday = toDateString(new Date(Date.now() - 86_400_000))

  const first = uniqueDays[0]

  // Streak must include today or yesterday to be considered active
  if (first === undefined || (first !== today && first !== yesterday)) return 0

  let streak = 1

  for (let i = 1; i < uniqueDays.length; i++) {
    // Bug fix 2: guard both values before using them in string concatenation.
    // noUncheckedIndexedAccess types array access as T | undefined.
    const prev = uniqueDays[i - 1]
    const curr = uniqueDays[i]

    if (prev === undefined || curr === undefined) break

    const prevDate = new Date(prev + 'T00:00:00Z')
    const currDate = new Date(curr + 'T00:00:00Z')
    const diffDays = Math.round(
      (prevDate.getTime() - currDate.getTime()) / 86_400_000,
    )

    if (diffDays === 1) {
      streak++
    } else {
      break
    }
  }

  return streak
}
