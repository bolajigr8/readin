import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { z } from 'zod'
import { UserData } from '../models/userData.model.js'
import { errorResponse, successResponse } from '../utils/response.utils.js'
import { accessFor, loadActor, type FeatureKey } from '../services/entitlements.service.js'

/** Which synced documents exist, and which feature (if any) gates them. */
const SYNC_KEYS: Record<string, FeatureKey | null> = {
  habits: 'habits', // premium / trial
  shelves: null, // free: statuses, shelves, favourites
}

const MAX_CHARS = 500_000

const putSchema = z.object({
  data: z.string().min(2).max(MAX_CHARS),
  baseVersion: z.number().int().min(0),
})

const resolve = async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return null
  }
  const key = String(req.params['key'] ?? '')
  if (!Object.prototype.hasOwnProperty.call(SYNC_KEYS, key)) {
    errorResponse(res, 'Unknown data set.', 404)
    return null
  }
  const actor = await loadActor(req.user.userId)
  if (!actor || actor.disabled) {
    errorResponse(res, 'Account unavailable.', 401)
    return null
  }
  const gate = SYNC_KEYS[key] ?? null
  if (gate) {
    const access = await accessFor(actor, gate)
    if (!access.allowed) {
      errorResponse(res, access.reason || 'This feature is not available.', 403, {
        code: 'FEATURE_LOCKED',
        access,
      })
      return null
    }
  }
  return { actorId: actor.id, key }
}

/** GET /sync/:key → { data: string | null, version } */
export const getSync = asyncHandler(async (req: Request, res: Response) => {
  const ctx = await resolve(req, res)
  if (!ctx) return
  const doc = await UserData.findOne({ userId: ctx.actorId, key: ctx.key }).lean()
  successResponse(res, { data: doc?.data ?? null, version: doc?.version ?? 0 }, 'OK')
})

/**
 * PUT /sync/:key { data, baseVersion }
 * Optimistic concurrency: the write only succeeds if `baseVersion` is still the
 * current version; otherwise 409 with the server copy so the phone can merge.
 */
export const putSync = asyncHandler(async (req: Request, res: Response) => {
  const ctx = await resolve(req, res)
  if (!ctx) return
  const parsed = putSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'Invalid data.', 400)
    return
  }
  const { data, baseVersion } = parsed.data

  // Must be a JSON object (the phone's own format) — never arbitrary text.
  try {
    const j: unknown = JSON.parse(data)
    if (typeof j !== 'object' || j === null || Array.isArray(j)) throw new Error('not an object')
  } catch {
    errorResponse(res, 'Data must be a JSON object.', 400)
    return
  }

  const conflict = async () => {
    const cur = await UserData.findOne({ userId: ctx.actorId, key: ctx.key }).lean()
    errorResponse(res, 'Out of date — merge and retry.', 409, {
      code: 'VERSION_CONFLICT',
      data: cur?.data ?? null,
      version: cur?.version ?? 0,
    })
  }

  if (baseVersion === 0) {
    try {
      const created = await UserData.create({ userId: ctx.actorId, key: ctx.key, data, version: 1 })
      successResponse(res, { version: created.version }, 'Saved.', 201)
    } catch {
      await conflict() // somebody created it first (unique index)
    }
    return
  }

  const updated = await UserData.findOneAndUpdate(
    { userId: ctx.actorId, key: ctx.key, version: baseVersion },
    { $set: { data }, $inc: { version: 1 } },
    { returnDocument: 'after' },
  )
  if (!updated) {
    await conflict()
    return
  }
  successResponse(res, { version: updated.version }, 'Saved.')
})
