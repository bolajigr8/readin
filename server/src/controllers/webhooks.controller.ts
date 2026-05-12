import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { User } from '../models/user.model.js'

// ── RevenueCat event shape ─────────────────────────────────────────────────────

interface RevenueCatEvent {
  type: string
  app_user_id: string
  product_id: string
  period_type: string
  expiration_at_ms: number
}

interface RevenueCatBody {
  event: RevenueCatEvent
}

// ── Event classification ──────────────────────────────────────────────────────

const PREMIUM_EVENTS = new Set([
  'INITIAL_PURCHASE',
  'RENEWAL',
  'UNCANCELLATION',
])

const FREE_EVENTS = new Set(['CANCELLATION', 'EXPIRATION', 'SUBSCRIBER_ALIAS'])

// ── Controller ────────────────────────────────────────────────────────────────

/**
 * POST /api/v1/webhooks/revenuecat
 * No auth middleware — RevenueCat authenticates via Authorization header.
 * Always returns 200 to acknowledge receipt (RevenueCat retries on non-200).
 */
export const revenueCatWebhook = asyncHandler(
  async (req: Request, res: Response) => {
    // 1. Verify authenticity
    const secret = process.env['REVENUECAT_WEBHOOK_SECRET']
    const authHeader = req.headers.authorization

    if (!secret || authHeader !== secret) {
      res.status(401).json({ success: false, message: 'Unauthorized.' })
      return
    }

    // 2. Parse body — express.json() already parsed it globally;
    //    express.raw() in the route is a safety net for any case where
    //    the raw Buffer arrives instead.
    let body: RevenueCatBody
    try {
      if (Buffer.isBuffer(req.body)) {
        body = JSON.parse(req.body.toString('utf-8')) as RevenueCatBody
      } else {
        body = req.body as RevenueCatBody
      }
    } catch {
      // Malformed body — still ack so RevenueCat doesn't retry endlessly
      console.error('[revenuecat] Failed to parse webhook body')
      res.status(200).json({ received: true })
      return
    }

    const { type, app_user_id } = body.event

    console.log(`[revenuecat] Event: ${type} | userId: ${app_user_id}`)

    // 3. Handle event
    if (PREMIUM_EVENTS.has(type)) {
      await User.findByIdAndUpdate(app_user_id, { plan: 'premium' })
      console.log(`[revenuecat] ✅ User ${app_user_id} upgraded to premium`)
    } else if (FREE_EVENTS.has(type)) {
      await User.findByIdAndUpdate(app_user_id, { plan: 'free' })
      console.log(`[revenuecat] ⬇️  User ${app_user_id} downgraded to free`)
    } else {
      console.log(`[revenuecat] Ignored event type: ${type}`)
    }

    // 4. Always acknowledge
    res.status(200).json({ received: true })
  },
)
