import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { z } from 'zod'
import mongoose from 'mongoose'

import { Annotation } from '../models/annotation.model.js'
import { successResponse, errorResponse } from '../utils/response.utils.js'

const FREE_PLAN_ANNOTATION_LIMIT = 20

const createAnnotationSchema = z.object({
  bookId: z.string().min(1, 'bookId is required'),
  type: z.enum(['highlight', 'note']),
  cfiRange: z.string().min(1, 'cfiRange is required'),
  selectedText: z.string().min(1, 'selectedText is required').max(2000),
  note: z.string().max(5000).default(''),
  color: z
    .enum(['yellow', 'green', 'blue', 'pink', 'purple'])
    .default('yellow'),
  chapterTitle: z.string().default(''),
  chapterIndex: z.number().int().min(0).default(0),
})

const updateAnnotationSchema = z.object({
  note: z.string().max(5000).optional(),
  color: z.enum(['yellow', 'green', 'blue', 'pink', 'purple']).optional(),
})

// ── createAnnotation ──────────────────────────────────────────────────────────

export const createAnnotation = asyncHandler(
  async (req: Request, res: Response) => {
    if (!req.user) {
      errorResponse(res, 'Not authenticated.', 401)
      return
    }

    const { userId, plan } = req.user

    const parsed = createAnnotationSchema.safeParse(req.body)
    if (!parsed.success) {
      errorResponse(
        res,
        'Validation failed',
        400,
        parsed.error.flatten().fieldErrors,
      )
      return
    }

    // Freemium gate
    if (plan === 'free') {
      const count = await Annotation.countDocuments({ userId })
      if (count >= FREE_PLAN_ANNOTATION_LIMIT) {
        errorResponse(
          res,
          `Free plan is limited to ${FREE_PLAN_ANNOTATION_LIMIT} annotations. Upgrade to Premium for unlimited annotations.`,
          403,
        )
        return
      }
    }

    const annotation = await Annotation.create({
      userId,
      ...parsed.data,
    })

    successResponse(res, { annotation }, 'Annotation created.', 201)
  },
)

// ── getAnnotations ────────────────────────────────────────────────────────────

export const getAnnotations = asyncHandler(
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

    const annotations = await Annotation.find({
      bookId,
      userId: req.user.userId,
    })
      .sort({ chapterIndex: 1, cfiRange: 1 })
      .lean()

    successResponse(res, { annotations })
  },
)

// ── updateAnnotation ──────────────────────────────────────────────────────────

export const updateAnnotation = asyncHandler(
  async (req: Request, res: Response) => {
    if (!req.user) {
      errorResponse(res, 'Not authenticated.', 401)
      return
    }

    const id = req.params['id']
    if (!id || !mongoose.isValidObjectId(id)) {
      errorResponse(res, 'Invalid annotation id.', 400)
      return
    }

    const parsed = updateAnnotationSchema.safeParse(req.body)
    if (!parsed.success) {
      errorResponse(
        res,
        'Validation failed',
        400,
        parsed.error.flatten().fieldErrors,
      )
      return
    }

    // Build update object — only include fields that were actually sent
    const update: { note?: string; color?: string } = {}
    if (parsed.data.note !== undefined) update.note = parsed.data.note
    if (parsed.data.color !== undefined) update.color = parsed.data.color

    const annotation = await Annotation.findOneAndUpdate(
      { _id: id, userId: req.user.userId },
      update,
      { new: true },
    )

    if (!annotation) {
      errorResponse(res, 'Annotation not found.', 404)
      return
    }

    successResponse(res, { annotation }, 'Annotation updated.')
  },
)

// ── deleteAnnotation ──────────────────────────────────────────────────────────

export const deleteAnnotation = asyncHandler(
  async (req: Request, res: Response) => {
    if (!req.user) {
      errorResponse(res, 'Not authenticated.', 401)
      return
    }

    const id = req.params['id']
    if (!id || !mongoose.isValidObjectId(id)) {
      errorResponse(res, 'Invalid annotation id.', 400)
      return
    }

    const annotation = await Annotation.findOneAndDelete({
      _id: id,
      userId: req.user.userId,
    })

    if (!annotation) {
      errorResponse(res, 'Annotation not found.', 404)
      return
    }

    successResponse(res, null, 'Annotation deleted.')
  },
)
