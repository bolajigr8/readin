import { Router } from 'express'
import { protect } from '../middleware/auth.middleware.js'
import { anyTeamMember, can, requireStaff } from '../middleware/admin.middleware.js'
import {
  getAudit,
  getBilling,
  listPayments,
  setBilling,
  testPaystack,
  runRemindersNow,
  verifyUserEmail,
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
import { createRelease, listReleases, updateRelease } from '../controllers/appRelease.controller.js'
import { addMember, getMe, listTeam, removeMember, updateMember } from '../controllers/team.controller.js'

const router = Router()

// Every admin route: a valid token, a team member checked in the DATABASE (owner / admin), and the permission
// for that route (S5). tests/admin-routes.test.mjs fails if a route below has no can(...).
router.use(protect, requireStaff)

router.get('/me', anyTeamMember, getMe)

router.get('/stats', can('dashboard.read'), getStats)
router.get('/audit', can('audit.read'), getAudit)
router.get('/config', can('features.read'), getConfig)
router.put('/config/features/:key', can('features.write'), setFeatureConfig)

router.get('/billing', can('billing.read'), getBilling)
router.put('/billing', can('billing.write'), setBilling)
router.post('/billing/test', can('billing.read'), testPaystack)
router.post('/billing/reminders/run', can('billing.write'), runRemindersNow)
router.get('/payments', can('payments.read'), listPayments)

router.get('/releases', can('releases.write'), listReleases)
router.post('/releases', can('releases.write'), createRelease)
router.patch('/releases/:id', can('releases.write'), updateRelease)

router.get('/users', can('users.read'), listUsers)
router.get('/users/:id', can('users.read'), getUser)
// plan / role need users.write and disabling needs users.disable — checked inside patchUser per field
router.patch('/users/:id', can('users.read'), patchUser)
router.post('/users/:id/verify', can('users.verify'), verifyUserEmail)
router.post('/users/:id/features/:key/grant', can('users.write'), grantFeature)
router.post('/users/:id/features/:key/revoke', can('users.write'), revokeFeature)
router.post('/users/:id/features/:key/restore', can('users.write'), restoreFeature)
router.post('/users/:id/features/:key/reset-trial', can('users.write'), resetTrial)

// Team (owners only: team.manage is never given to an admin)
router.get('/team', can('team.manage'), listTeam)
router.post('/team', can('team.manage'), addMember)
router.patch('/team/:id', can('team.manage'), updateMember)
router.delete('/team/:id', can('team.manage'), removeMember)

export default router
