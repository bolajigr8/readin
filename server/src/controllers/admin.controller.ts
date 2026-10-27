import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { Types } from 'mongoose'
import { z } from 'zod'
import { AdminAudit } from '../models/adminAudit.model.js'
import { AppConfig } from '../models/appConfig.model.js'
import { Book } from '../models/book.model.js'
import { User } from '../models/user.model.js'
import { UserFeature } from '../models/userFeature.model.js'
import { Payment } from '../models/payment.model.js'
import { getBillingConfig, invalidateBillingConfig } from '../services/billing.service.js'
import {
  MAX_PLANS,
  MAX_PRICE_KOBO,
  MIN_PRICE_KOBO,
  formatNaira,
  normalizePlansInput,
} from '../services/billing.logic.js'
import { paystackConfigured, paystackMode, publicBaseUrl } from '../services/paystack.service.js'
import { errorResponse, successResponse } from '../utils/response.utils.js'
import {
  FEATURE_KEYS,
  evaluateAccess,
  getFeatureConfig,
  invalidateFeatureConfig,
  isFeatureKey,
  toState,
  type Access,
} from '../services/entitlements.service.js'

// ── helpers ───────────────────────────────────────────────────────────────────

const escapeRegex = (s: string): string => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

const audit = async (
  req: Request,
  action: string,
  targetUserId: string | null,
  details: unknown,
): Promise<void> => {
  try {
    await AdminAudit.create({
      adminId: req.user?.userId,
      action,
      targetUserId,
      details,
      ip: req.ip ?? '',
    } as never)
  } catch (err) {
    console.error('[admin] audit failed:', err)
  }
}

const userIdParam = (req: Request, res: Response): string | null => {
  const id = String(req.params['id'] ?? '')
  if (!Types.ObjectId.isValid(id)) {
    errorResponse(res, 'Invalid user id.', 400)
    return null
  }
  return id
}

const featureParam = (req: Request, res: Response) => {
  const key = String(req.params['key'] ?? '')
  if (!isFeatureKey(key)) {
    errorResponse(res, 'Unknown feature.', 404)
    return null
  }
  return key
}

// ── config ────────────────────────────────────────────────────────────────────

/** GET /admin/config */
export const getConfig = asyncHandler(async (_req: Request, res: Response) => {
  invalidateFeatureConfig()
  successResponse(res, { features: await getFeatureConfig(), keys: FEATURE_KEYS }, 'OK')
})

const featureConfigSchema = z
  .object({
    enabled: z.boolean().optional(),
    trialDays: z.number().int().min(0).max(365).optional(),
    includedInPremium: z.boolean().optional(),
    freeForAll: z.boolean().optional(),
  })
  .strict()

/** PUT /admin/config/features/:key  { enabled?, trialDays?, includedInPremium? } */
export const setFeatureConfig = asyncHandler(async (req: Request, res: Response) => {
  const key = featureParam(req, res)
  if (!key) return
  const parsed = featureConfigSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'Invalid settings.', 400)
    return
  }
  const set: Record<string, unknown> = { updatedBy: req.user?.userId ?? null }
  for (const [field, value] of Object.entries(parsed.data)) {
    if (value !== undefined) set[`features.${key}.${field}`] = value
  }
  await AppConfig.updateOne({ key: 'features' }, { $set: set }, { upsert: true })
  invalidateFeatureConfig()
  await audit(req, 'config.feature', null, { key, ...parsed.data })
  successResponse(res, { features: await getFeatureConfig() }, 'Saved.')
})

// ── users ─────────────────────────────────────────────────────────────────────

/** GET /admin/users?search=&page=&limit= */
export const listUsers = asyncHandler(async (req: Request, res: Response) => {
  const search = String(req.query['search'] ?? '').trim().slice(0, 80)
  const page = Math.max(1, Number(req.query['page'] ?? 1) || 1)
  const limit = Math.min(100, Math.max(1, Number(req.query['limit'] ?? 25) || 25))

  const filter = search
    ? {
        $or: [
          { email: { $regex: escapeRegex(search), $options: 'i' } },
          { displayName: { $regex: escapeRegex(search), $options: 'i' } },
        ],
      }
    : {}

  const [items, total] = await Promise.all([
    User.find(filter)
      .select('email displayName plan role disabled isEmailVerified createdAt lastLoginAt')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .lean(),
    User.countDocuments(filter),
  ])

  successResponse(
    res,
    {
      items: items.map((u) => ({
        id: String(u._id),
        email: u.email,
        displayName: u.displayName,
        plan: u.plan,
        role: u.role ?? 'user',
        disabled: u.disabled === true,
        isEmailVerified: u.isEmailVerified,
        createdAt: u.createdAt,
        lastLoginAt: u.lastLoginAt ?? null,
      })),
      total,
      page,
      limit,
    },
    'OK',
  )
})

/** GET /admin/users/:id — profile + feature access + a few counts */
export const getUser = asyncHandler(async (req: Request, res: Response) => {
  const id = userIdParam(req, res)
  if (!id) return
  const u = await User.findById(id)
    .select('email displayName plan role disabled isEmailVerified createdAt lastLoginAt premiumUntil')
    .lean()
  if (!u) {
    errorResponse(res, 'User not found.', 404)
    return
  }
  const [config, rows, books] = await Promise.all([
    getFeatureConfig(),
    UserFeature.find({ userId: id }).lean(),
    Book.countDocuments({ userId: id }),
  ])
  const features: Record<string, Access & { trialStartedAt: string | null; revoked: boolean }> = {}
  for (const key of FEATURE_KEYS) {
    const row = rows.find((r) => r.key === key)
    const access = evaluateAccess({
      role: u.role === 'admin' ? 'admin' : 'user',
      plan: u.plan === 'premium' ? 'premium' : 'free',
      config: config[key],
      uf: toState(row),
    })
    features[key] = {
      ...access,
      trialStartedAt: row?.trialStartedAt ? row.trialStartedAt.toISOString() : null,
      revoked: row?.revoked === true,
    }
  }
  successResponse(
    res,
    {
      user: {
        id: String(u._id),
        email: u.email,
        displayName: u.displayName,
        plan: u.plan,
        role: u.role ?? 'user',
        disabled: u.disabled === true,
        isEmailVerified: u.isEmailVerified,
        createdAt: u.createdAt,
        lastLoginAt: u.lastLoginAt ?? null,
        premiumUntil: u.premiumUntil ?? null,
      },
      features,
      books,
    },
    'OK',
  )
})

const patchUserSchema = z
  .object({
    plan: z.enum(['free', 'premium']).optional(),
    disabled: z.boolean().optional(),
  })
  .strict()

/**
 * PATCH /admin/users/:id { plan?, disabled? }
 * Administrators cannot be changed here (role changes happen only through the
 * create-admin script on the server) — so a stolen admin token cannot demote,
 * disable or lock out the real admin.
 */
export const patchUser = asyncHandler(async (req: Request, res: Response) => {
  const id = userIdParam(req, res)
  if (!id) return
  const parsed = patchUserSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'Invalid change.', 400)
    return
  }
  const u = await User.findById(id)
  if (!u) {
    errorResponse(res, 'User not found.', 404)
    return
  }
  if (u.role === 'admin') {
    errorResponse(res, 'Administrator accounts cannot be changed here.', 403)
    return
  }
  if (parsed.data.plan !== undefined) u.plan = parsed.data.plan
  if (parsed.data.disabled !== undefined) {
    u.disabled = parsed.data.disabled
    if (parsed.data.disabled) u.refreshTokens = [] // sign them out everywhere
  }
  await u.save()
  await audit(req, 'user.patch', id, parsed.data)
  successResponse(res, { id, plan: u.plan, disabled: u.disabled }, 'Saved.')
})

// ── per-user feature controls ─────────────────────────────────────────────────

const grantSchema = z.object({ days: z.number().int().min(1).max(3650) })

const ensureRow = async (userId: string, key: string): Promise<void> => {
  await UserFeature.updateOne(
    { userId, key },
    { $setOnInsert: { trialStartedAt: null, grantedUntil: null, revoked: false } },
    { upsert: true },
  )
}

/** POST /admin/users/:id/features/:key/grant { days } — full access for N days */
export const grantFeature = asyncHandler(async (req: Request, res: Response) => {
  const id = userIdParam(req, res)
  const key = featureParam(req, res)
  if (!id || !key) return
  const parsed = grantSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'days must be a whole number from 1 to 3650.', 400)
    return
  }
  await ensureRow(id, key)
  const row = await UserFeature.findOne({ userId: id, key })
  const from = row?.grantedUntil && row.grantedUntil.getTime() > Date.now() ? row.grantedUntil : new Date()
  const until = new Date(from.getTime() + parsed.data.days * 24 * 3600 * 1000)
  await UserFeature.updateOne({ userId: id, key }, { $set: { grantedUntil: until, revoked: false } })
  await audit(req, 'feature.grant', id, { key, days: parsed.data.days, until })
  successResponse(res, { grantedUntil: until.toISOString() }, 'Granted.')
})

/** POST /admin/users/:id/features/:key/revoke — block the feature for this user */
export const revokeFeature = asyncHandler(async (req: Request, res: Response) => {
  const id = userIdParam(req, res)
  const key = featureParam(req, res)
  if (!id || !key) return
  await ensureRow(id, key)
  await UserFeature.updateOne({ userId: id, key }, { $set: { revoked: true, grantedUntil: null } })
  await audit(req, 'feature.revoke', id, { key })
  successResponse(res, {}, 'Revoked.')
})

/** POST /admin/users/:id/features/:key/restore — remove a block / grant */
export const restoreFeature = asyncHandler(async (req: Request, res: Response) => {
  const id = userIdParam(req, res)
  const key = featureParam(req, res)
  if (!id || !key) return
  await ensureRow(id, key)
  await UserFeature.updateOne({ userId: id, key }, { $set: { revoked: false, grantedUntil: null } })
  await audit(req, 'feature.restore', id, { key })
  successResponse(res, {}, 'Restored.')
})

/** POST /admin/users/:id/features/:key/reset-trial — a fresh trial from the next open */
export const resetTrial = asyncHandler(async (req: Request, res: Response) => {
  const id = userIdParam(req, res)
  const key = featureParam(req, res)
  if (!id || !key) return
  await ensureRow(id, key)
  await UserFeature.updateOne({ userId: id, key }, { $set: { trialStartedAt: null } })
  await audit(req, 'feature.reset-trial', id, { key })
  successResponse(res, {}, 'Trial reset.')
})

// ── overview + audit ──────────────────────────────────────────────────────────

/** GET /admin/stats */
export const getStats = asyncHandler(async (_req: Request, res: Response) => {
  const since7 = new Date(Date.now() - 7 * 24 * 3600 * 1000)
  const monthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1)
  const sum = async (match: Record<string, unknown>): Promise<number> => {
    const r = await Payment.aggregate<{ total: number }>([
      { $match: { status: 'success', ...match } },
      { $group: { _id: null, total: { $sum: '$amountKobo' } } },
    ])
    return r[0]?.total ?? 0
  }
  const [users, premium, disabled, newThisWeek, books, trials, paymentsCount, revenueKobo, revenueMonthKobo] =
    await Promise.all([
      User.countDocuments({}),
      User.countDocuments({ plan: 'premium' }),
      User.countDocuments({ disabled: true }),
      User.countDocuments({ createdAt: { $gte: since7 } }),
      Book.countDocuments({}),
      UserFeature.countDocuments({ key: 'habits', trialStartedAt: { $ne: null } }),
      Payment.countDocuments({ status: 'success' }),
      sum({}),
      sum({ paidAt: { $gte: monthStart } }),
    ])
  successResponse(
    res,
    {
      users,
      premium,
      disabled,
      newThisWeek,
      books,
      habitsTrialsStarted: trials,
      paymentsCount,
      revenueKobo,
      revenueMonthKobo,
    },
    'OK',
  )
})

/** GET /admin/audit?limit= — latest admin actions */
export const getAudit = asyncHandler(async (req: Request, res: Response) => {
  const limit = Math.min(200, Math.max(1, Number(req.query['limit'] ?? 50) || 50))
  const rows = await AdminAudit.find({}).sort({ createdAt: -1 }).limit(limit).lean()
  successResponse(
    res,
    {
      items: rows.map((r) => ({
        id: String(r._id),
        adminId: String(r.adminId),
        action: r.action,
        targetUserId: r.targetUserId ? String(r.targetUserId) : null,
        details: r.details,
        ip: r.ip,
        createdAt: r.createdAt,
      })),
    },
    'OK',
  )
})

// ── e-mail verification by hand ───────────────────────────────────────────────

/** POST /admin/users/:id/verify — mark the e-mail as confirmed (no link needed). */
export const verifyUserEmail = asyncHandler(async (req: Request, res: Response) => {
  const id = userIdParam(req, res)
  if (!id) return
  const r = await User.updateOne(
    { _id: id },
    { $set: { isEmailVerified: true, emailVerificationToken: null, emailVerificationExpires: null } },
  )
  if (r.matchedCount === 0) {
    errorResponse(res, 'User not found.', 404)
    return
  }
  await audit(req, 'user.verify-email', id, null)
  successResponse(res, { isEmailVerified: true }, 'E-mail marked as verified.')
})

// ── billing (Paystack) ────────────────────────────────────────────────────────

const planSchema = z
  .object({
    id: z.string().max(60).optional(),
    name: z.string().trim().min(1).max(40),
    description: z.string().trim().max(120).optional(),
    priceKobo: z.number().int().min(MIN_PRICE_KOBO).max(MAX_PRICE_KOBO),
    durationDays: z.number().int().min(1).max(3650),
    active: z.boolean(),
    badge: z.string().trim().max(20).optional(),
  })
  .strict()

const billingSchema = z
  .object({
    enabled: z.boolean().optional(),
    freeLibraryLimit: z.number().int().min(1).max(1000).optional(),
    plans: z.array(planSchema).max(MAX_PLANS).optional(),
  })
  .strict()

const billingView = async () => ({
  billing: await getBillingConfig(),
  paystack: {
    configured: paystackConfigured(),
    mode: paystackMode(),
    callbackUrl: `${publicBaseUrl()}/payment/callback`,
    webhookUrl: `${publicBaseUrl()}/api/v1/webhooks/paystack`,
  },
})

/** GET /admin/billing */
export const getBilling = asyncHandler(async (_req: Request, res: Response) => {
  invalidateBillingConfig()
  successResponse(res, await billingView(), 'OK')
})

/**
 * PUT /admin/billing { enabled?, freeLibraryLimit?, plans? }
 * Prices are in KOBO (₦1 = 100 kobo). Turning payments ON needs Paystack keys on
 * the server and at least one active plan.
 */
export const setBilling = asyncHandler(async (req: Request, res: Response) => {
  const parsed = billingSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'Invalid billing settings (check names and prices).', 400)
    return
  }
  const current = await getBillingConfig()
  const next = {
    ...current,
    ...(parsed.data.enabled === undefined ? {} : { enabled: parsed.data.enabled }),
    ...(parsed.data.freeLibraryLimit === undefined ? {} : { freeLibraryLimit: parsed.data.freeLibraryLimit }),
    ...(parsed.data.plans === undefined ? {} : { plans: normalizePlansInput(parsed.data.plans) }),
  }

  if (next.enabled && !paystackConfigured()) {
    errorResponse(
      res,
      'Paystack is not connected. Add PAYSTACK_SECRET_KEY to the server settings first, then turn payments on.',
      400,
    )
    return
  }
  if (next.enabled && !next.plans.some((p) => p.active)) {
    errorResponse(res, 'Add at least one ACTIVE plan before turning payments on.', 400)
    return
  }

  await AppConfig.updateOne(
    { key: 'features' },
    { $set: { billing: next, updatedBy: req.user?.userId ?? null } },
    { upsert: true },
  )
  invalidateBillingConfig()
  await audit(req, 'billing.update', null, {
    enabled: next.enabled,
    freeLibraryLimit: next.freeLibraryLimit,
    plans: next.plans.map((p) => `${p.name}: ${formatNaira(p.priceKobo)} / ${p.durationDays}d${p.active ? '' : ' (off)'}`),
  })
  successResponse(res, await billingView(), 'Saved.')
})

/** GET /admin/payments?status=&page=&limit= */
export const listPayments = asyncHandler(async (req: Request, res: Response) => {
  const page = Math.max(1, Number(req.query['page'] ?? 1) || 1)
  const limit = Math.min(100, Math.max(1, Number(req.query['limit'] ?? 25) || 25))
  const wanted = (['pending', 'success', 'failed', 'abandoned'] as const).find(
    (st) => st === String(req.query['status'] ?? ''),
  )
  const filter: { status?: 'pending' | 'success' | 'failed' | 'abandoned' } = wanted ? { status: wanted } : {}
  const [rows, total] = await Promise.all([
    Payment.find(filter)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .lean(),
    Payment.countDocuments(filter),
  ])
  successResponse(
    res,
    {
      items: rows.map((p) => ({
        id: String(p._id),
        userId: String(p.userId),
        email: p.email,
        planName: p.planName,
        amountKobo: p.amountKobo,
        amountText: formatNaira(p.amountKobo),
        status: p.status,
        channel: p.channel,
        reference: p.reference,
        paidAt: p.paidAt,
        premiumUntil: p.premiumUntil,
        createdAt: p.createdAt,
      })),
      total,
      page,
      limit,
    },
    'OK',
  )
})
