import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { UserFeature } from '../models/userFeature.model.js'
import { errorResponse, successResponse } from '../utils/response.utils.js'
import {
  FEATURE_KEYS,
  accessFor,
  evaluateAccess,
  getFeatureConfig,
  isFeatureKey,
  loadActor,
  toState,
  type Access,
} from '../services/entitlements.service.js'

/** GET /features/me — what the signed-in user may use (trial days left etc.). */
export const getMyFeatures = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }
  const actor = await loadActor(req.user.userId)
  if (!actor || actor.disabled) {
    errorResponse(res, 'Account unavailable.', 401)
    return
  }
  const [config, rows] = await Promise.all([
    getFeatureConfig(),
    UserFeature.find({ userId: actor.id }).lean(),
  ])
  const features: Record<string, Access> = {}
  for (const key of FEATURE_KEYS) {
    const row = rows.find((r) => r.key === key)
    features[key] = evaluateAccess({
      role: actor.role,
      plan: actor.plan,
      config: config[key],
      uf: toState(row),
    })
  }
  successResponse(res, { features, serverTime: new Date().toISOString() }, 'OK')
})

/**
 * POST /features/:key/start-trial — idempotent. The trial clock starts once,
 * on the server; calling it again never extends it.
 */
export const startTrial = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }
  const key = String(req.params['key'] ?? '')
  if (!isFeatureKey(key)) {
    errorResponse(res, 'Unknown feature.', 404)
    return
  }
  const actor = await loadActor(req.user.userId)
  if (!actor || actor.disabled) {
    errorResponse(res, 'Account unavailable.', 401)
    return
  }

  const before = await accessFor(actor, key)
  if (before.canStartTrial) {
    await UserFeature.updateOne(
      { userId: actor.id, key },
      { $setOnInsert: { revoked: false, grantedUntil: null } },
      { upsert: true },
    )
    // Only if it was never started (guards against double taps / races).
    await UserFeature.updateOne(
      { userId: actor.id, key, trialStartedAt: null },
      { $set: { trialStartedAt: new Date() } },
    )
  }
  const access = await accessFor(actor, key)
  successResponse(res, { access }, before.canStartTrial ? 'Trial started.' : 'OK')
})
