import { Router } from 'express'
import { protect } from '../middleware/auth.middleware.js'
import { getSync, putSync } from '../controllers/sync.controller.js'

const router = Router()

router.get('/:key', protect, getSync)
router.put('/:key', protect, putSync)

export default router
