import { Router } from 'express'
import { protect } from '../middleware/auth.middleware.js'
import { getMyFeatures, startTrial } from '../controllers/features.controller.js'

const router = Router()

router.get('/me', protect, getMyFeatures)
router.post('/:key/start-trial', protect, startTrial)

export default router
