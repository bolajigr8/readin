import { Router } from 'express'
import { protect } from '../middleware/auth.middleware.js'
import {
  getLibrary,
  getBook,
  deleteBook,
  saveDiscoveredBook,
  registerLocalBook,
} from '../controllers/library.controller.js'

const router = Router()

router.get('/', protect, getLibrary)
router.post('/discover', protect, saveDiscoveredBook)
router.post('/local', protect, registerLocalBook)
router.get('/:bookId', protect, getBook)
router.delete('/:bookId', protect, deleteBook)

export default router
