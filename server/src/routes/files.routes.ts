import { Router } from 'express'
import { protect } from '../middleware/auth.middleware.js'
import { uploadSingle } from '../middleware/upload.middleware.js'
import { uploadFile, getJobStatus } from '../controllers/files.controller.js'
import { uploadLimiter } from '../middleware/rateLimit.middleware.js'

const router = Router()

// uploadLimiter scoped to the upload endpoint only (20/hr per IP)
router.post('/upload', uploadLimiter, protect, uploadSingle, uploadFile)
router.get('/job/:jobId', protect, getJobStatus)

export default router
