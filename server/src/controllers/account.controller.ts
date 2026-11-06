import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import bcrypt from 'bcryptjs'
import { z } from 'zod'
import { User } from '../models/user.model.js'
import { deleteAccount, hashDeletionToken, newDeletionToken } from '../services/accountDeletion.service.js'
import { emailService } from '../services/email/email.service.js'
import { errorResponse, successResponse } from '../utils/response.utils.js'

/**
 * Account deletion (S7.1). Two ways, both required by Google Play:
 *  - in the app:  DELETE /api/v1/users/me            { password }   (or { confirm: "DELETE" } without a password)
 *  - on the web:  POST /api/v1/auth/delete-account/request { email } → e-mail with a 1-hour link
 *                 → page /delete-account/confirm?token=… → POST /api/v1/auth/delete-account/confirm { token }
 */

const deleteMeSchema = z.object({
  password: z.string().max(200).optional(),
  confirm: z.string().max(20).optional(),
})

/** DELETE /api/v1/users/me — the signed-in user deletes their own account. */
export const deleteMe = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }
  const parsed = deleteMeSchema.safeParse(req.body ?? {})
  if (!parsed.success) {
    errorResponse(res, 'Please fill in the form again.', 400)
    return
  }
  const user = await User.findById(req.user.userId).select('passwordHash')
  if (!user) {
    errorResponse(res, 'Account not found.', 404)
    return
  }
  if (user.passwordHash) {
    const ok = !!parsed.data.password && (await bcrypt.compare(parsed.data.password, user.passwordHash))
    if (!ok) {
      // 403, not 401: a 401 makes the app think its sign-in expired (refresh + retry).
      errorResponse(res, 'That password is not correct.', 403)
      return
    }
  } else if ((parsed.data.confirm ?? '').trim().toUpperCase() !== 'DELETE') {
    errorResponse(res, 'Type DELETE to confirm.', 400)
    return
  }
  await deleteAccount(user._id, 'app')
  successResponse(res, null, 'Your account was deleted.')
})

const requestSchema = z.object({ email: z.string().email().max(200) })

const SAFE_REQUEST_MESSAGE =
  'If an account with that e-mail exists, we have sent a link to confirm the deletion. It works for 1 hour.'

/** POST /api/v1/auth/delete-account/request — web form. Same answer whether the account exists or not. */
export const requestAccountDeletion = asyncHandler(async (req: Request, res: Response) => {
  const parsed = requestSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'Enter a valid e-mail address.', 400)
    return
  }
  const user = await User.findOne({ email: parsed.data.email.toLowerCase() })
  if (!user) {
    successResponse(res, null, SAFE_REQUEST_MESSAGE)
    return
  }
  // At most one e-mail per minute per account (stops someone flooding a stranger's inbox).
  const issuedAt = user.accountDeletionExpires ? user.accountDeletionExpires.getTime() - 60 * 60 * 1000 : 0
  if (Date.now() - issuedAt < 60_000) {
    successResponse(res, null, SAFE_REQUEST_MESSAGE)
    return
  }
  const t = newDeletionToken()
  user.accountDeletionTokenHash = t.hash
  user.accountDeletionExpires = t.expires
  await user.save()
  emailService
    .sendAccountDeletionLinkEmail(user.email, user.displayName, t.token)
    .catch((err: unknown) => console.error('[account] deletion link e-mail failed:', err))
  successResponse(res, null, SAFE_REQUEST_MESSAGE)
})

/** Valid, unexpired deletion link? (used by the confirmation page) */
export const isDeletionTokenValid = async (token: string): Promise<boolean> => {
  if (!token || token.length > 200) return false
  const user = await User.findOne({
    accountDeletionTokenHash: hashDeletionToken(token),
    accountDeletionExpires: { $gt: new Date() },
  }).select('_id')
  return !!user
}

const confirmSchema = z.object({ token: z.string().min(1).max(200) })

/** POST /api/v1/auth/delete-account/confirm — the button on the confirmation page. */
export const confirmAccountDeletion = asyncHandler(async (req: Request, res: Response) => {
  const parsed = confirmSchema.safeParse(req.body)
  const user = parsed.success
    ? await User.findOne({
        accountDeletionTokenHash: hashDeletionToken(parsed.data.token),
        accountDeletionExpires: { $gt: new Date() },
      }).select('_id')
    : null
  if (!user) {
    errorResponse(res, 'This link is not valid any more. Ask for a new one on the delete-account page.', 400)
    return
  }
  await deleteAccount(user._id, 'web')
  successResponse(res, null, 'Your account was deleted.')
})
