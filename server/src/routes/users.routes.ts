import { Router } from 'express'
import { protect } from '../middleware/auth.middleware.js'
import { savePushToken } from '../controllers/users.controller.js'

const router = Router()

router.put('/push-token', protect, savePushToken)

export default router
