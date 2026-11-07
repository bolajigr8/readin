import { effectiveRole, ownerEmails, type Role } from './roles.logic.js'

/** The role that counts for this account (ADMIN_EMAILS + verified e-mail = owner). */
export const roleOf = (u: { role?: unknown; email: string; isEmailVerified?: boolean | null }): Role =>
  effectiveRole(u, ownerEmails(process.env['ADMIN_EMAILS']))
