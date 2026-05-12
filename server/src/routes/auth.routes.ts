import { Router } from 'express'
import {
  register,
  login,
  googleOAuth,
  refreshToken,
  logout,
  verifyEmail,
  forgotPassword,
  resetPassword,
} from '../controllers/auth.controller.js'

const router = Router()

router.post('/register', register)
router.post('/login', login)
router.post('/google', googleOAuth)
router.post('/refresh', refreshToken)
router.post('/logout', logout)
router.get('/verify-email/:token', verifyEmail)
router.post('/forgot-password', forgotPassword)
router.post('/reset-password', resetPassword)

export default router
