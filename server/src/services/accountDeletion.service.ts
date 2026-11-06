import { createHash, randomBytes } from 'node:crypto'
import type { Types } from 'mongoose'
import { AdminAudit } from '../models/adminAudit.model.js'
import { Annotation } from '../models/annotation.model.js'
import { Book } from '../models/book.model.js'
import { Bookmark } from '../models/bookmark.model.js'
import { Job } from '../models/job.model.js'
import { Payment } from '../models/payment.model.js'
import { Progress } from '../models/progress.model.js'
import { User } from '../models/user.model.js'
import { UserData } from '../models/userData.model.js'
import { UserFeature } from '../models/userFeature.model.js'
import { cloudinaryService } from './cloudinary.service.js'
import { emailService } from './email/email.service.js'

/**
 * Account deletion (S7.1 — Google Play requires it in the app AND on the web).
 *
 * Deleted for good: the account (e-mail, name, password, sign-ins), every book + its files in
 * Cloudinary, notes/highlights, bookmarks, reading progress, synced data (habits, settings),
 * trials and conversion jobs.
 * Kept WITHOUT personal data: payment records (amount, date, plan, reference — accounting, tax
 * and fraud checks; the e-mail is removed) and one audit line "account deleted" (no e-mail, no IP).
 * Every signed-in phone stops working at once: `protect` re-reads the user on each request.
 */

export const DELETION_LINK_TTL_MS = 60 * 60 * 1000 // the web confirmation link works for 1 hour

/** Only the hash is stored, so a database leak cannot be used to delete accounts. */
export const hashDeletionToken = (token: string): string => createHash('sha256').update(token).digest('hex')

export const newDeletionToken = (): { token: string; hash: string; expires: Date } => {
  const token = randomBytes(32).toString('hex')
  return { token, hash: hashDeletionToken(token), expires: new Date(Date.now() + DELETION_LINK_TTL_MS) }
}

export interface DeletionSummary {
  books: number
  files: number
  annotations: number
  bookmarks: number
  progress: number
  syncedItems: number
  trials: number
  jobs: number
  paymentsAnonymised: number
}

/** Deletes everything that belongs to [userId]. Safe to call again (nothing left = zeros). */
export const deleteAccount = async (
  userId: Types.ObjectId | string,
  via: 'app' | 'web',
): Promise<DeletionSummary | null> => {
  const user = await User.findById(userId).select('email displayName')
  if (!user) return null

  // Goodbye e-mail first (we still know the address). Fire-and-forget like every other e-mail.
  emailService
    .sendAccountDeletedEmail(user.email, user.displayName)
    .catch((err: unknown) => console.error('[account] goodbye e-mail failed:', err))

  // Files in Cloudinary (uploaded books keep the same file as original + converted → de-duplicate).
  const books = await Book.find({ userId: user._id }).select('originalFilePublicId convertedFilePublicId')
  const publicIds = [
    ...new Set(
      books
        .flatMap((b) => [b.convertedFilePublicId, b.originalFilePublicId])
        .filter((id): id is string => typeof id === 'string' && id.length > 0),
    ),
  ]
  let files = 0
  await Promise.all(
    publicIds.map((id) =>
      cloudinaryService
        .deleteFile(id)
        .then(() => {
          files++
        })
        .catch((err: unknown) => {
          // Not fatal: the account must still disappear. Logged for a manual clean-up.
          console.warn('[account] could not delete a file from Cloudinary:', id, err)
        }),
    ),
  )

  const owner = { userId: user._id }
  const [b, a, bm, p, d, f, j, pay] = await Promise.all([
    Book.deleteMany(owner),
    Annotation.deleteMany(owner),
    Bookmark.deleteMany(owner),
    Progress.deleteMany(owner),
    UserData.deleteMany(owner),
    UserFeature.deleteMany(owner),
    Job.deleteMany(owner),
    Payment.updateMany(owner, { $set: { email: '' } }),
  ])

  const summary: DeletionSummary = {
    books: b.deletedCount,
    files,
    annotations: a.deletedCount,
    bookmarks: bm.deletedCount,
    progress: p.deletedCount,
    syncedItems: d.deletedCount,
    trials: f.deletedCount,
    jobs: j.deletedCount,
    paymentsAnonymised: pay.modifiedCount,
  }

  try {
    await AdminAudit.create({
      adminId: user._id, // the person deleted their own account
      action: 'account.deleted_by_user',
      targetUserId: user._id,
      details: { via, ...summary },
      ip: '',
    } as never)
  } catch (err) {
    console.error('[account] audit failed:', err)
  }

  await User.deleteOne({ _id: user._id })
  console.log(`[account] account deleted (${via}): books ${summary.books}, files ${summary.files}`)
  return summary
}
