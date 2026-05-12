import { Router } from 'express'
import { protect } from '../middleware/auth.middleware.js'
import {
  saveProgress,
  getProgress,
  getReadingStats,
} from '../controllers/progress.controller.js'

const router = Router()

// Static route must come before dynamic :bookId to avoid collision
router.get('/stats/me', protect, getReadingStats)
router.put('/:bookId', protect, saveProgress)
router.get('/:bookId', protect, getProgress)

export default router
