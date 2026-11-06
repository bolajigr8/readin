import { Router } from 'express'
import { protect } from '../middleware/auth.middleware.js'
import { getMe, savePushToken } from '../controllers/users.controller.js'
import { deleteMe } from '../controllers/account.controller.js'
import { authLimiter } from '../middleware/rateLimit.middleware.js'

const router = Router()

router.get('/me', protect, getMe)
router.put('/push-token', protect, savePushToken)
// Delete my account (S7.1). authLimiter: wrong passwords count like failed sign-ins.
router.delete('/me', authLimiter, protect, deleteMe)

export default router
