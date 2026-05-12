import { Router } from 'express'
import { protect } from '../middleware/auth.middleware.js'
import {
  createBookmark,
  getBookmarks,
  deleteBookmark,
} from '../controllers/bookmarks.controller.js'

const router = Router()

router.post('/', protect, createBookmark)
router.get('/book/:bookId', protect, getBookmarks)
router.delete('/:id', protect, deleteBookmark)

export default router
