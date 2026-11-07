import { Router } from 'express'
import { protect } from '../middleware/auth.middleware.js'
import { getStatus, setReminders, startPremiumTrial } from '../controllers/billing.controller.js'

const router = Router()

router.get('/status', protect, getStatus)
router.post('/trial', protect, startPremiumTrial)
router.patch('/reminders', protect, setReminders)

export default router
