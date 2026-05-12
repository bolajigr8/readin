import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { z } from 'zod'
import mongoose from 'mongoose'

import { Bookmark } from '../models/bookmark.model.js'
import { successResponse, errorResponse } from '../utils/response.utils.js'

const createBookmarkSchema = z.object({
  bookId: z.string().min(1, 'bookId is required'),
  cfi: z.string().min(1, 'cfi is required'),
  label: z.string().max(200).default(''),
  chapterTitle: z.string().default(''),
  chapterIndex: z.number().int().min(0).default(0),
  percentage: z.number().min(0).max(100).default(0),
})

// ── createBookmark ────────────────────────────────────────────────────────────

export const createBookmark = asyncHandler(
  async (req: Request, res: Response) => {
    if (!req.user) {
      errorResponse(res, 'Not authenticated.', 401)
      return
    }

    const { userId } = req.user

    const parsed = createBookmarkSchema.safeParse(req.body)
    if (!parsed.success) {
      errorResponse(
        res,
        'Validation failed',
        400,
        parsed.error.flatten().fieldErrors,
      )
      return
    }

    const { bookId, cfi } = parsed.data

    // Return existing bookmark if the exact CFI already exists for this user + book
    const existing = await Bookmark.findOne({ userId, bookId, cfi })
    if (existing) {
      successResponse(res, { bookmark: existing }, 'Bookmark already exists.')
      return
    }

    const bookmark = await Bookmark.create({ userId, ...parsed.data })

    successResponse(res, { bookmark }, 'Bookmark created.', 201)
  },
)

// ── getBookmarks ──────────────────────────────────────────────────────────────

export const getBookmarks = asyncHandler(
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

    const bookmarks = await Bookmark.find({
      bookId,
      userId: req.user.userId,
    })
      .sort({ chapterIndex: 1 })
      .lean()

    successResponse(res, { bookmarks })
  },
)

// ── deleteBookmark ────────────────────────────────────────────────────────────

export const deleteBookmark = asyncHandler(
  async (req: Request, res: Response) => {
    if (!req.user) {
      errorResponse(res, 'Not authenticated.', 401)
      return
    }

    const id = req.params['id']
    if (!id || !mongoose.isValidObjectId(id)) {
      errorResponse(res, 'Invalid bookmark id.', 400)
      return
    }

    const bookmark = await Bookmark.findOneAndDelete({
      _id: id,
      userId: req.user.userId,
    })

    if (!bookmark) {
      errorResponse(res, 'Bookmark not found.', 404)
      return
    }

    successResponse(res, null, 'Bookmark deleted.')
  },
)
