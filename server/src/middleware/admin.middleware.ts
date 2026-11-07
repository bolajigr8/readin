import type { NextFunction, Request, Response } from 'express'
import { User } from '../models/user.model.js'
import {
  effectivePermissions,
  effectiveRole,
  isStaff,
  ownerEmails,
  type Permission,
} from '../services/roles.logic.js'
import { errorResponse } from '../utils/response.utils.js'

/**
 * requireStaff — use AFTER `protect`. Only owners and admins (S5). Read from the DATABASE on every request
 * (never from the token); disabled accounts are refused. An e-mail in ADMIN_EMAILS with a verified account is
 * always an owner (break-glass). Failures answer a plain 403 so nothing about the admin API leaks.
 */
export const requireStaff = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    if (!req.user) {
      errorResponse(res, 'Not authenticated.', 401)
      return
    }
    const u = await User.findById(req.user.userId).select('role permissions email disabled isEmailVerified').lean()
    if (!u || u.disabled === true) {
      errorResponse(res, 'Forbidden.', 403)
      return
    }
    const role = effectiveRole(u, ownerEmails(process.env['ADMIN_EMAILS']))
    if (!isStaff(role)) {
      errorResponse(res, 'Forbidden.', 403)
      return
    }
    req.staff = { role, permissions: effectivePermissions(role, u.permissions) }
    next()
  } catch (err) {
    next(err)
  }
}

/** Kept for older imports: the same as requireStaff. */
export const requireAdmin = requireStaff

type Guard = ((req: Request, res: Response, next: NextFunction) => void) & { permission: Permission }

/** `can('billing.write')` — the signed-in team member must have this permission (use after requireStaff). */
export const can = (permission: Permission): Guard => {
  const guard = ((req: Request, res: Response, next: NextFunction): void => {
    if (!req.staff?.permissions.includes(permission)) {
      errorResponse(res, "You don't have permission for this. Ask an owner of ReadIn.", 403)
      return
    }
    next()
  }) as Guard
  guard.permission = permission
  return guard
}

/** For routes every team member may use (e.g. /admin/me). Marks the route as checked for the route test. */
export const anyTeamMember = (_req: Request, _res: Response, next: NextFunction): void => next()
