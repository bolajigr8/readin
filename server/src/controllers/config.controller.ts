import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { getBillingConfig } from '../services/billing.service.js'
import { publicBilling } from '../services/billing.logic.js'
import { getFeatureConfig } from '../services/entitlements.service.js'
import { successResponse } from '../utils/response.utils.js'

/**
 * GET /api/v1/config/public — what the app needs to draw itself: is billing
 * visible, the active plans (naira), and each feature's rules. No secrets, no auth.
 */
export const getPublicConfig = asyncHandler(async (_req: Request, res: Response) => {
  const [billing, features] = await Promise.all([getBillingConfig(), getFeatureConfig()])
  res.setHeader('Cache-Control', 'public, max-age=15')
  successResponse(res, {
    billing: publicBilling(billing),
    features,
    serverTime: new Date().toISOString(),
  })
})
