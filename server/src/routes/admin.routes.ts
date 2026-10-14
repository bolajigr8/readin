import { Router } from 'express'
import { protect } from '../middleware/auth.middleware.js'
import { requireAdmin } from '../middleware/admin.middleware.js'
import {
  getAudit,
  getConfig,
  getStats,
  getUser,
  grantFeature,
  listUsers,
  patchUser,
  resetTrial,
  restoreFeature,
  revokeFeature,
  setFeatureConfig,
} from '../controllers/admin.controller.js'

const router = Router()

// Every admin route needs a valid token AND a database-verified administrator.
router.use(protect, requireAdmin)

router.get('/stats', getStats)
router.get('/audit', getAudit)
router.get('/config', getConfig)
router.put('/config/features/:key', setFeatureConfig)

router.get('/users', listUsers)
router.get('/users/:id', getUser)
router.patch('/users/:id', patchUser)
router.post('/users/:id/features/:key/grant', grantFeature)
router.post('/users/:id/features/:key/revoke', revokeFeature)
router.post('/users/:id/features/:key/restore', restoreFeature)
router.post('/users/:id/features/:key/reset-trial', resetTrial)

export default router
