import { Router } from 'express'
import { protect } from '../middleware/auth.middleware.js'
import {
  createAnnotation,
  getAnnotations,
  updateAnnotation,
  deleteAnnotation,
} from '../controllers/annotations.controller.js'

const router = Router()

router.post('/', protect, createAnnotation)
router.get('/book/:bookId', protect, getAnnotations)
router.put('/:id', protect, updateAnnotation)
router.delete('/:id', protect, deleteAnnotation)

export default router
