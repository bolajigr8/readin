import { Router } from 'express'
import {
  landing,
  paymentCallback,
  resetPasswordPageHandler,
  verifyEmailPageHandler,
} from '../controllers/pages.controller.js'

/** Browser pages (HTML) — mounted at the site root, outside /api. */
const router = Router()

router.get('/', landing)
router.get('/verify-email', verifyEmailPageHandler)
router.get('/reset-password', resetPasswordPageHandler)
router.get('/payment/callback', paymentCallback)

export default router
