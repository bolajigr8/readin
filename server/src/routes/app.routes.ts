import { Router } from 'express'
import { getVersion } from '../controllers/appRelease.controller.js'

/** Public app information (no login). */
const router = Router()

router.get('/version', getVersion)

export default router
