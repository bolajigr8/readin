import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { z } from 'zod'
import mongoose from 'mongoose'

import { ALL_FORMATS, Book, type OriginalFormat } from '../models/book.model.js'
import { Annotation } from '../models/annotation.model.js'
import { Bookmark } from '../models/bookmark.model.js'
import { Progress } from '../models/progress.model.js'
import { cloudinaryService } from '../services/cloudinary.service.js'
import { successResponse, errorResponse } from '../utils/response.utils.js'

const FREE_PLAN_LIBRARY_LIMIT = 10

const discoverSchema = z.object({
  gutenbergId: z.string().min(1, 'gutenbergId is required'),
  title: z.string().min(1, 'title is required'),
  author: z.string().default(''),
  description: z.string().default(''),
  coverUrl: z.string().url().or(z.literal('')).default(''),
  epubUrl: z.string().url('epubUrl must be a valid URL'),
  language: z.string().default('en'),
  genre: z.string().default(''),
})

// ── getLibrary ────────────────────────────────────────────────────────────────

export const getLibrary = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }

  const { userId, plan } = req.user

  const page = Math.max(1, Number(req.query['page'] ?? '1'))
  const limit = Math.min(50, Math.max(1, Number(req.query['limit'] ?? '20')))
  const skip = (page - 1) * limit

  const [books, total] = await Promise.all([
    Book.find({ userId, status: 'ready' })
      .select(
        'title author description coverUrl originalFileUrl convertedFileUrl originalFormat status source gutenbergId language genre fileSize fingerprint jobId createdAt updatedAt',
      )
      .sort({ updatedAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    Book.countDocuments({ userId, status: 'ready' }),
  ])

  // Join reading progress for each book in a single query
  const bookIds = books.map((b) => b._id)
  const progressRecords = await Progress.find({
    userId,
    bookId: { $in: bookIds },
  })
    .select('bookId percentage lastReadAt isCompleted')
    .lean()

  const progressMap = new Map(
    progressRecords.map((p) => [p.bookId.toString(), p]),
  )

  const enrichedBooks = books.map((book) => {
    const progress = progressMap.get(book._id.toString())
    return {
      ...book,
      progress: progress
        ? {
            percentage: progress.percentage,
            lastReadAt: progress.lastReadAt,
            isCompleted: progress.isCompleted,
          }
        : null,
    }
  })

  const limitReached = plan === 'free' && total >= FREE_PLAN_LIBRARY_LIMIT

  successResponse(res, {
    books: enrichedBooks,
    meta: {
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
      limitReached,
    },
  })
})

// ── getBook ───────────────────────────────────────────────────────────────────

export const getBook = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }

  const bookId = req.params['bookId']
  if (!bookId || !mongoose.isValidObjectId(bookId)) {
    errorResponse(res, 'Invalid bookId.', 400)
    return
  }

  const [book, progress, annotationCount] = await Promise.all([
    Book.findOne({ _id: bookId, userId: req.user.userId }).lean(),
    Progress.findOne({ bookId, userId: req.user.userId }).lean(),
    Annotation.countDocuments({ bookId, userId: req.user.userId }),
  ])

  if (!book) {
    errorResponse(res, 'Book not found.', 404)
    return
  }

  successResponse(res, { book, progress, annotationCount })
})

// ── deleteBook ────────────────────────────────────────────────────────────────

export const deleteBook = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }

  const bookId = req.params['bookId']
  if (!bookId || !mongoose.isValidObjectId(bookId)) {
    errorResponse(res, 'Invalid bookId.', 400)
    return
  }

  const book = await Book.findOne({ _id: bookId, userId: req.user.userId })
  if (!book) {
    errorResponse(res, 'Book not found.', 404)
    return
  }

  // Delete the stored file(s) from Cloudinary. Uploaded books keep the SAME
  // file as original + converted while conversion is on hold, so de-duplicate
  // the public ids. Discover books have no Cloudinary files at all.
  const publicIds = [
    ...new Set(
      [book.convertedFilePublicId, book.originalFilePublicId].filter(
        (id): id is string => typeof id === 'string' && id.length > 0,
      ),
    ),
  ]
  await Promise.all(
    publicIds.map((id) =>
      cloudinaryService.deleteFile(id).catch((err: unknown) => {
        console.warn('[library] Could not delete file from Cloudinary:', id, err)
      }),
    ),
  )

  // Delete all associated data in parallel
  await Promise.all([
    Annotation.deleteMany({ bookId }),
    Bookmark.deleteMany({ bookId }),
    Progress.deleteMany({ bookId }),
    book.deleteOne(),
  ])

  successResponse(res, null, 'Book deleted successfully.')
})

// ── saveDiscoveredBook ────────────────────────────────────────────────────────

export const saveDiscoveredBook = asyncHandler(
  async (req: Request, res: Response) => {
    if (!req.user) {
      errorResponse(res, 'Not authenticated.', 401)
      return
    }

    const { userId, plan } = req.user

    const parsed = discoverSchema.safeParse(req.body)
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
      gutenbergId,
      title,
      author,
      description,
      coverUrl,
      epubUrl,
      language,
      genre,
    } = parsed.data

    // Check if already in library
    const existing = await Book.findOne({ userId, gutenbergId })
    if (existing) {
      errorResponse(res, 'This book is already in your library.', 409)
      return
    }

    // Freemium gate
    if (plan === 'free') {
      const count = await Book.countDocuments({ userId, status: 'ready' })
      if (count >= FREE_PLAN_LIBRARY_LIMIT) {
        errorResponse(
          res,
          `Free plan is limited to ${FREE_PLAN_LIBRARY_LIMIT} books. Upgrade to Premium for unlimited access.`,
          403,
        )
        return
      }
    }

    const book = await Book.create({
      userId,
      title,
      author,
      description,
      coverUrl,
      convertedFileUrl: epubUrl, // EPUB is hosted on Gutenberg CDN — no conversion needed
      originalFormat: 'epub',
      status: 'ready',
      source: 'discover',
      gutenbergId,
      language,
      genre,
    })

    successResponse(res, { book }, 'Book saved to library.', 201)
  },
)

// ── registerLocalBook (local-first) ───────────────────────────────────────────
// The FILE stays on the user's phone. The server only keeps a record (title,
// format, size, fingerprint) so progress, highlights, notes and bookmarks sync
// and the book shows up on every device of the user.

const localSchema = z.object({
  title: z.string().trim().min(1, 'title is required').max(300),
  author: z.string().trim().max(300).default(''),
  format: z
    .string()
    .trim()
    .toLowerCase()
    .transform((f) => ((ALL_FORMATS as readonly string[]).includes(f) ? f : 'other')),
  fileSize: z.number().int().min(0).default(0),
  fingerprint: z.string().trim().max(128).default(''),
  language: z.string().default('en'),
})

export const registerLocalBook = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }
  const parsed = localSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, parsed.error.issues[0]?.message ?? 'Invalid request.', 400)
    return
  }
  const { userId, plan } = req.user
  const d = parsed.data

  // Same file imported again (or on a second phone): return the existing record.
  if (d.fingerprint) {
    const existing = await Book.findOne({ userId, fingerprint: d.fingerprint, status: 'ready' }).lean()
    if (existing) {
      successResponse(res, { book: existing, deduped: true }, 'Book already in your library.', 200)
      return
    }
  }

  if (plan === 'free') {
    const count = await Book.countDocuments({ userId, status: 'ready' })
    if (count >= FREE_PLAN_LIBRARY_LIMIT) {
      errorResponse(
        res,
        `Free plan is limited to ${FREE_PLAN_LIBRARY_LIMIT} books. Upgrade to Premium for unlimited access.`,
        403,
      )
      return
    }
  }

  const book = await Book.create({
    userId,
    title: d.title,
    author: d.author,
    originalFormat: d.format as OriginalFormat,
    fileSize: d.fileSize,
    fingerprint: d.fingerprint,
    language: d.language,
    status: 'ready',
    source: 'local',
  })

  successResponse(res, { book: book.toObject() }, 'Book registered.', 201)
})
