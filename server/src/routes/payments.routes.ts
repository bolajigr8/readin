import { Router } from 'express'
import { protect } from '../middleware/auth.middleware.js'
import { checkout, history, verify } from '../controllers/payments.controller.js'

const router = Router()

router.post('/checkout', protect, checkout)
router.get('/verify/:reference', protect, verify)
router.get('/history', protect, history)

export default router
