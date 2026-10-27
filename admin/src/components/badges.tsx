import { Badge } from '@/components/ui/badge'
import type { AccessState, UserRow } from '@/lib/types'

const ACCESS: Record<AccessState, { label: string; variant: 'success' | 'info' | 'warning' | 'danger' | 'secondary' }> = {
  full: { label: 'Full access', variant: 'success' },
  trial: { label: 'Free trial', variant: 'info' },
  trial_available: { label: 'Trial not started', variant: 'secondary' },
  expired: { label: 'Trial ended', variant: 'warning' },
  locked: { label: 'Locked', variant: 'danger' },
  disabled: { label: 'Switched off', variant: 'danger' },
}

export function AccessBadge({ state }: { state: AccessState }) {
  const a = ACCESS[state] ?? { label: state, variant: 'secondary' as const }
  return <Badge variant={a.variant}>{a.label}</Badge>
}

export function PlanBadge({ plan }: { plan: UserRow['plan'] }) {
  return plan === 'premium' ? <Badge>Premium</Badge> : <Badge variant="secondary">Free</Badge>
}

export function StatusBadges({ user }: { user: Pick<UserRow, 'role' | 'disabled' | 'isEmailVerified'> }) {
  return (
    <span className="flex flex-wrap gap-1">
      {user.role === 'admin' && <Badge variant="info">Admin</Badge>}
      {user.disabled && <Badge variant="danger">Disabled</Badge>}
      {!user.isEmailVerified && <Badge variant="warning">Unverified</Badge>}
    </span>
  )
}
