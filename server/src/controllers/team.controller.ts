import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import bcrypt from 'bcryptjs'
import mongoose from 'mongoose'
import { z } from 'zod'
import { AdminAudit } from '../models/adminAudit.model.js'
import { User } from '../models/user.model.js'
import {
  PERMISSION_LABELS,
  PERMISSIONS,
  PRESETS,
  cleanPermissions,
  effectivePermissions,
  ownerEmails,
  teamChangeProblem,
  type Role,
} from '../services/roles.logic.js'
import { roleOf } from '../services/roles.service.js'
import { clientIp } from '../utils/clientIp.js'
import { errorResponse, successResponse } from '../utils/response.utils.js'

// ── who am I (every team member) ──────────────────────────────────────────────

/** GET /admin/me — role + permissions so the panel can hide what this person cannot use. */
export const getMe = asyncHandler(async (req: Request, res: Response) => {
  const u = await User.findById(req.user?.userId).select('email displayName').lean()
  successResponse(res, {
    email: u?.email ?? '',
    displayName: u?.displayName ?? '',
    role: req.staff?.role ?? 'user',
    permissions: req.staff?.permissions ?? [],
  })
})

// ── team (owners) ─────────────────────────────────────────────────────────────

const audit = async (req: Request, action: string, targetUserId: string, details: unknown): Promise<void> => {
  try {
    await AdminAudit.create({ adminId: req.user?.userId, action, targetUserId, details, ip: clientIp(req) } as never)
  } catch (err) {
    console.error('[admin] audit failed:', err)
  }
}

/** Owners right now: owner in the database, or a verified ADMIN_EMAILS account. */
const countOwners = async (): Promise<number> => {
  const listed = ownerEmails(process.env['ADMIN_EMAILS'])
  return User.countDocuments({
    disabled: { $ne: true },
    $or: [{ role: 'owner' }, ...(listed.length ? [{ email: { $in: listed }, isEmailVerified: true }] : [])],
  })
}

/** Team changes need the owner's own password again (a stolen session alone cannot change the team). */
const passwordOk = async (req: Request, password: string): Promise<boolean> => {
  const me = await User.findById(req.user?.userId).select('passwordHash').lean()
  return !!me?.passwordHash && (await bcrypt.compare(password, me.passwordHash))
}

const memberView = (u: {
  _id: unknown
  email: string
  displayName: string
  role?: unknown
  permissions?: string[] | null
  isEmailVerified?: boolean | null
  lastLoginAt?: Date | null
  roleChangedAt?: Date | null
  disabled?: boolean | null
}) => {
  const role = roleOf(u)
  return {
    id: String(u._id),
    email: u.email,
    displayName: u.displayName,
    role,
    permissions: effectivePermissions(role, u.permissions),
    /** Owner because of ADMIN_EMAILS on the server (cannot be removed here). */
    fixedOwner: ownerEmails(process.env['ADMIN_EMAILS']).includes(u.email.toLowerCase()) && u.isEmailVerified === true,
    lastLoginAt: u.lastLoginAt ?? null,
    roleChangedAt: u.roleChangedAt ?? null,
    disabled: u.disabled === true,
  }
}

/** GET /admin/team — the team + the permission list and presets for the form. */
export const listTeam = asyncHandler(async (_req: Request, res: Response) => {
  const listed = ownerEmails(process.env['ADMIN_EMAILS'])
  const rows = await User.find({
    $or: [{ role: { $in: ['owner', 'admin'] } }, ...(listed.length ? [{ email: { $in: listed } }] : [])],
  })
    .select('email displayName role permissions isEmailVerified lastLoginAt roleChangedAt disabled')
    .sort({ role: -1, email: 1 })
    .limit(200)
    .lean()
  successResponse(res, {
    items: rows.map(memberView).filter((m) => m.role === 'owner' || m.role === 'admin'),
    permissions: PERMISSIONS.filter((p) => p !== 'team.manage').map((p) => ({ key: p, label: PERMISSION_LABELS[p] })),
    presets: Object.entries(PRESETS).map(([key, v]) => ({ key, label: v.label, permissions: v.permissions })),
  })
})

const memberSchema = z
  .object({
    role: z.enum(['admin', 'owner']),
    permissions: z.array(z.string().max(40)).max(PERMISSIONS.length).optional(),
    password: z.string().min(1).max(200),
  })
  .strict()

const applyRole = async (
  req: Request,
  res: Response,
  target: InstanceType<typeof User>,
  nextRole: Role,
  permissions: string[],
  action: string,
): Promise<boolean> => {
  const before = { role: roleOf(target), permissions: effectivePermissions(roleOf(target), target.permissions) }
  const problem = teamChangeProblem({
    actorId: req.user?.userId ?? '',
    targetId: String(target._id),
    targetIsOwnerNow: before.role === 'owner',
    targetWillBeOwner: nextRole === 'owner',
    ownersNow: await countOwners(),
  })
  if (problem) {
    errorResponse(res, problem, 409)
    return false
  }
  if (ownerEmails(process.env['ADMIN_EMAILS']).includes(target.email.toLowerCase()) && nextRole !== 'owner') {
    errorResponse(res, 'This owner is set in the server settings (ADMIN_EMAILS) and cannot be changed here.', 409)
    return false
  }
  target.role = nextRole
  target.permissions = nextRole === 'admin' ? cleanPermissions(permissions) : []
  target.roleChangedAt = new Date()
  target.roleChangedBy = req.user ? (new mongoose.Types.ObjectId(req.user.userId) as never) : null
  target.refreshTokens = [] // their sessions end: the new rights apply from their next sign-in (and right away on the API)
  await target.save()
  await audit(req, action, String(target._id), {
    before,
    after: { role: nextRole, permissions: effectivePermissions(nextRole, target.permissions) },
  })
  return true
}

/** POST /admin/team { email, role, permissions?, password } — the person needs a confirmed ReadIn account. */
export const addMember = asyncHandler(async (req: Request, res: Response) => {
  const parsed = memberSchema.extend({ email: z.string().trim().toLowerCase().email().max(200) }).strict().safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'Please enter the e-mail, the role and your password.', 400)
    return
  }
  if (!(await passwordOk(req, parsed.data.password))) {
    errorResponse(res, 'Your password is not correct.', 403)
    return
  }
  const target = await User.findOne({ email: parsed.data.email })
  if (!target || !target.isEmailVerified) {
    errorResponse(res, 'This person needs a ReadIn account with a confirmed e-mail first. Ask them to sign up in the app, then try again.', 404)
    return
  }
  if (target.disabled) {
    errorResponse(res, 'This account is switched off. Switch it on first.', 409)
    return
  }
  const current = roleOf(target)
  if (current === 'owner' || current === 'admin') {
    errorResponse(res, 'This person is already in the team — edit them in the list.', 409)
    return
  }
  if (await applyRole(req, res, target, parsed.data.role, parsed.data.permissions ?? [], 'team.add')) {
    successResponse(res, memberView(target), `${target.email} is now ${parsed.data.role === 'owner' ? 'an owner' : 'an admin'}.`, 201)
  }
})

const idParam = (req: Request, res: Response): string | null => {
  const id = String(req.params['id'] ?? '')
  if (!mongoose.isValidObjectId(id)) {
    errorResponse(res, 'Team member not found.', 404)
    return null
  }
  return id
}

/** PATCH /admin/team/:id { role, permissions?, password } */
export const updateMember = asyncHandler(async (req: Request, res: Response) => {
  const id = idParam(req, res)
  if (!id) return
  const parsed = memberSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'Please choose the role and enter your password.', 400)
    return
  }
  if (!(await passwordOk(req, parsed.data.password))) {
    errorResponse(res, 'Your password is not correct.', 403)
    return
  }
  const target = await User.findById(id)
  const current = target ? roleOf(target) : 'user'
  if (!target || (current !== 'owner' && current !== 'admin')) {
    errorResponse(res, 'Team member not found.', 404)
    return
  }
  if (await applyRole(req, res, target, parsed.data.role, parsed.data.permissions ?? [], 'team.update')) {
    successResponse(res, memberView(target), 'Saved.')
  }
})

/** DELETE /admin/team/:id { password } — back to a normal user (the account itself stays). */
export const removeMember = asyncHandler(async (req: Request, res: Response) => {
  const id = idParam(req, res)
  if (!id) return
  const parsed = z.object({ password: z.string().min(1).max(200) }).strict().safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'Please enter your password.', 400)
    return
  }
  if (!(await passwordOk(req, parsed.data.password))) {
    errorResponse(res, 'Your password is not correct.', 403)
    return
  }
  const target = await User.findById(id)
  const current = target ? roleOf(target) : 'user'
  if (!target || (current !== 'owner' && current !== 'admin')) {
    errorResponse(res, 'Team member not found.', 404)
    return
  }
  if (await applyRole(req, res, target, 'user', [], 'team.remove')) {
    successResponse(res, memberView(target), `${target.email} is no longer in the team.`)
  }
})
