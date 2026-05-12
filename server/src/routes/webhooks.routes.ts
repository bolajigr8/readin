import { Router } from 'express'
import express from 'express'
import { revenueCatWebhook } from '../controllers/webhooks.controller.js'

const router = Router()

// express.raw() captures the body before the global express.json() can touch it
// when the route is mounted before global body parsing.
// In our app.ts the global parser runs first, so this acts as a safety fallback.
router.post(
  '/revenuecat',
  express.raw({ type: 'application/json' }),
  revenueCatWebhook,
)

export default router
