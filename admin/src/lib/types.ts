// Shapes returned by the ReadIn admin API (server/src/controllers/admin.controller.ts).

export interface Stats {
  users: number
  premium: number
  disabled: number
  newThisWeek: number
  books: number
  habitsTrialsStarted: number
  paymentsCount: number
  /** Money in kobo (₦1 = 100 kobo). */
  revenueKobo: number
  revenueMonthKobo: number
}

export type AccessState = 'full' | 'trial' | 'trial_available' | 'expired' | 'locked' | 'disabled'

export interface FeatureAccess {
  state: AccessState
  allowed: boolean
  canStartTrial: boolean
  reason: string
  trialEndsAt: string | null
  daysLeft: number | null
  grantedUntil: string | null
}

export interface UserRow {
  id: string
  email: string
  displayName: string
  plan: 'free' | 'premium'
  role: 'user' | 'admin'
  disabled: boolean
  isEmailVerified: boolean
  createdAt: string
  lastLoginAt: string | null
  /** End of the paid period (from RevenueCat); only in the detail view. */
  premiumUntil?: string | null
}

export interface UsersPage {
  items: UserRow[]
  total: number
  page: number
  limit: number
}

export interface UserFeatureDetail extends FeatureAccess {
  trialStartedAt: string | null
  revoked: boolean
}

export interface UserDetail {
  user: UserRow
  features: Record<string, UserFeatureDetail>
  books: number
}

export interface FeatureConfig {
  enabled: boolean
  trialDays: number
  includedInPremium: boolean
  freeForAll: boolean
}

export interface AdminConfig {
  features: Record<string, FeatureConfig>
  keys: string[]
}

export interface AuditItem {
  id: string
  adminId: string
  action: string
  targetUserId: string | null
  details: unknown
  ip: string
  createdAt: string
}

/** Friendly names for the feature keys the API knows about. */
export const FEATURE_LABELS: Record<string, { name: string; description: string }> = {
  habits: {
    name: 'Reading Habit Tracker',
    description: 'Daily pages goals, calendar, streaks and reminders.',
  },
}

// ── billing ───────────────────────────────────────────────────────────────────

export interface Plan {
  id: string
  name: string
  description: string
  /** Kobo: ₦1,500 = 150000. */
  priceKobo: number
  durationDays: number
  active: boolean
  badge: string
}

export interface BillingConfig {
  enabled: boolean
  currency: 'NGN'
  plans: Plan[]
  freeLibraryLimit: number
}

export interface BillingView {
  billing: BillingConfig
  paystack: {
    configured: boolean
    mode: 'test' | 'live' | 'not configured'
    callbackUrl: string
    webhookUrl: string
  }
}

export interface PaymentRow {
  id: string
  userId: string
  email: string
  planName: string
  amountKobo: number
  amountText: string
  status: 'pending' | 'success' | 'failed' | 'abandoned'
  channel: string
  reference: string
  paidAt: string | null
  premiumUntil: string | null
  createdAt: string
}

export interface PaymentsPage {
  items: PaymentRow[]
  total: number
  page: number
  limit: number
}
