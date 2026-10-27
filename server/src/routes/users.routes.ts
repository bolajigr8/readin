import { Router } from 'express'
import { protect } from '../middleware/auth.middleware.js'
import { getMe, savePushToken } from '../controllers/users.controller.js'

const router = Router()

router.get('/me', protect, getMe)
router.put('/push-token', protect, savePushToken)

export default router
