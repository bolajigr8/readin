import { Router } from 'express'
import {
  register,
  login,
  googleOAuth,
  refreshToken,
  logout,
  verifyEmail,
  resendVerification,
  forgotPassword,
  resetPassword,
} from '../controllers/auth.controller.js'
import { confirmAccountDeletion, requestAccountDeletion } from '../controllers/account.controller.js'

const router = Router()

router.post('/register', register)
router.post('/login', login)
router.post('/google', googleOAuth)
router.post('/refresh', refreshToken)
router.post('/logout', logout)
router.get('/verify-email/:token', verifyEmail)
router.post('/resend-verification', resendVerification)
router.post('/forgot-password', forgotPassword)
router.post('/reset-password', resetPassword)
// Web account deletion (S7.1): e-mail link → confirmation page → this button.
router.post('/delete-account/request', requestAccountDeletion)
router.post('/delete-account/confirm', confirmAccountDeletion)

export default router
