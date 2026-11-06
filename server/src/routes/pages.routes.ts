import { Router } from 'express'
import {
  landing,
  paymentCallback,
  deleteAccountPage,
  deleteAccountConfirmPageHandler,
  resetPasswordPageHandler,
  verifyEmailPageHandler,
} from '../controllers/pages.controller.js'

/** Browser pages (HTML) — mounted at the site root, outside /api. */
const router = Router()

router.get('/', landing)
router.get('/verify-email', verifyEmailPageHandler)
router.get('/reset-password', resetPasswordPageHandler)
router.get('/payment/callback', paymentCallback)
router.get('/delete-account', deleteAccountPage)
router.get('/delete-account/confirm', deleteAccountConfirmPageHandler)

export default router
