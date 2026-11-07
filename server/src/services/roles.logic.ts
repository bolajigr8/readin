/**
 * Roles & permissions (S5) — pure rules, no database. Unit-tested in tests/roles.test.mjs.
 *
 *   owner  — everything, incl. the Team page. At least one must always exist.
 *   admin  — only the permissions an owner gave it (never team.manage).
 *   tester — no admin panel; every feature + Premium-equivalent in the app (people helping to test).
 *   user   — normal rules.
 */

export type Role = 'user' | 'tester' | 'admin' | 'owner'
export const ROLES: readonly Role[] = ['user', 'tester', 'admin', 'owner']

export const PERMISSIONS = [
  'dashboard.read',
  'users.read',
  'users.write',
  'users.disable',
  'users.verify',
  'features.read',
  'features.write',
  'billing.read',
  'billing.write',
  'payments.read',
  'releases.write',
  'audit.read',
  'team.manage',
] as const
export type Permission = (typeof PERMISSIONS)[number]

/** Plain-language one-liners for the Team page. */
export const PERMISSION_LABELS: Record<Permission, string> = {
  'dashboard.read': 'See the dashboard numbers',
  'users.read': 'Look up users',
  'users.write': 'Change a user’s plan, gifts, trials and tester role',
  'users.disable': 'Switch accounts off / on',
  'users.verify': 'Mark an e-mail as confirmed',
  'features.read': 'See feature settings',
  'features.write': 'Change feature settings',
  'billing.read': 'See prices and payment settings',
  'billing.write': 'Change prices, trial, reminders and the payments switch',
  'payments.read': 'See payments',
  'releases.write': 'Add and publish app versions',
  'audit.read': 'Read the audit log',
  'team.manage': 'Manage the team (owners only)',
}

const ALL_BUT_TEAM = PERMISSIONS.filter((p) => p !== 'team.manage')

export const PRESETS: Record<'full' | 'support' | 'releases' | 'finance', { label: string; permissions: Permission[] }> = {
  full: { label: 'Full admin (everything except the team)', permissions: [...ALL_BUT_TEAM] },
  support: { label: 'Support', permissions: ['dashboard.read', 'users.read', 'users.verify', 'users.disable', 'payments.read'] },
  releases: { label: 'Release manager', permissions: ['dashboard.read', 'features.read', 'releases.write'] },
  finance: { label: 'Finance viewer', permissions: ['dashboard.read', 'billing.read', 'payments.read'] },
}

export const isPermission = (p: unknown): p is Permission => typeof p === 'string' && (PERMISSIONS as readonly string[]).includes(p)
export const isStaff = (role: Role): boolean => role === 'owner' || role === 'admin'

/** A stored role string → a known role ('admin' accounts from before S5 stay 'admin'). */
export const parseRole = (r: unknown): Role => (ROLES as readonly unknown[]).includes(r) ? (r as Role) : 'user'

/** e-mails from ADMIN_EMAILS (comma-separated, lower case). */
export const ownerEmails = (env: string | undefined): string[] =>
  (env ?? '')
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean)

/**
 * The role that counts. A verified account whose e-mail is in ADMIN_EMAILS is always an OWNER
 * (break-glass: the owner can never be locked out by a wrong database value).
 */
export const effectiveRole = (
  u: { role?: unknown; email: string; isEmailVerified?: boolean | null },
  owners: readonly string[],
): Role => {
  if (u.isEmailVerified === true && owners.includes(u.email.toLowerCase())) return 'owner'
  return parseRole(u.role)
}

/** What a role may do in the admin panel. */
export const effectivePermissions = (role: Role, stored: readonly unknown[] | null | undefined): Permission[] => {
  if (role === 'owner') return [...PERMISSIONS]
  if (role !== 'admin') return []
  return PERMISSIONS.filter((p) => p !== 'team.manage' && (stored ?? []).includes(p))
}

/** Clean a requested permission list (unknown ones dropped, team.manage never given to an admin). */
export const cleanPermissions = (list: readonly unknown[]): Permission[] =>
  PERMISSIONS.filter((p) => p !== 'team.manage' && list.includes(p))

/** Testers and the team use the app like Premium members (they must be able to test everything). */
export const planForRole = (role: Role, plan: 'free' | 'premium'): 'free' | 'premium' => (role === 'user' ? plan : 'premium')

/** Can [actorId] change [target]? A plain-language reason when not (null = allowed). */
export const teamChangeProblem = (input: {
  actorId: string
  targetId: string
  targetIsOwnerNow: boolean
  targetWillBeOwner: boolean
  ownersNow: number
}): string | null => {
  if (input.actorId === input.targetId) return 'You cannot change your own role — ask another owner.'
  if (input.targetIsOwnerNow && !input.targetWillBeOwner && input.ownersNow <= 1) {
    return 'This is the last owner. Make someone else an owner first.'
  }
  return null
}
