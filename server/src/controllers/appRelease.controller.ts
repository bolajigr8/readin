import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import mongoose from 'mongoose'
import { z } from 'zod'
import { AppRelease, type IAppRelease } from '../models/appRelease.model.js'
import { AdminAudit } from '../models/adminAudit.model.js'
import {
  CHANNELS,
  VERSION_RE,
  checkDownloadUrl,
  cleanNotes,
  decideUpdate,
  latestPublished,
  type ReleaseChannel,
} from '../services/appRelease.logic.js'
import { clientIp } from '../utils/clientIp.js'
import { errorResponse, successResponse } from '../utils/response.utils.js'

// ── public: does this phone need an update? ───────────────────────────────────

let cache: { at: number; rows: IAppRelease[] } | null = null
const CACHE_MS = 60_000
const published = async (): Promise<IAppRelease[]> => {
  if (cache && Date.now() - cache.at < CACHE_MS) return cache.rows
  const rows = await AppRelease.find({ published: true }).sort({ versionCode: -1 }).limit(20)
  cache = { at: Date.now(), rows }
  return rows
}
const invalidate = (): void => {
  cache = null
}

/**
 * GET /api/v1/app/version?channel=direct|play&versionCode=2
 * Public (no login), cacheable 60 s. Unknown channel → "direct"; unknown versionCode → never mandatory.
 */
export const getVersion = asyncHandler(async (req: Request, res: Response) => {
  const channel: ReleaseChannel = req.query['channel'] === 'play' ? 'play' : 'direct'
  const code = Number.parseInt(String(req.query['versionCode'] ?? '0'), 10)
  const answer = decideUpdate(latestPublished(await published(), channel), Number.isFinite(code) && code > 0 ? code : 0)
  res.setHeader('Cache-Control', 'public, max-age=60')
  successResponse(res, { channel, ...answer })
})

// ── admin ─────────────────────────────────────────────────────────────────────

const view = (r: IAppRelease) => ({
  id: String(r._id),
  channel: r.channel,
  version: r.version,
  versionCode: r.versionCode,
  downloadUrl: r.downloadUrl,
  sha256: r.sha256,
  sizeBytes: r.sizeBytes,
  notes: r.notes,
  mandatory: r.mandatory,
  minSupportedVersionCode: r.minSupportedVersionCode,
  published: r.published,
  releasedAt: r.releasedAt,
  createdAt: r.createdAt,
})

const audit = async (req: Request, action: string, details: unknown): Promise<void> => {
  try {
    await AdminAudit.create({ adminId: req.user?.userId, action, targetUserId: null, details, ip: clientIp(req) } as never)
  } catch (err) {
    console.error('[admin] audit failed:', err)
  }
}

const releaseSchema = z
  .object({
    channel: z.enum(CHANNELS as [ReleaseChannel, ...ReleaseChannel[]]),
    version: z.string().trim().regex(VERSION_RE),
    versionCode: z.number().int().min(1).max(2_100_000_000),
    downloadUrl: z.string().trim().max(500),
    sha256: z
      .string()
      .trim()
      .regex(/^([a-f0-9]{64})?$/i)
      .optional(),
    sizeBytes: z.number().int().min(0).max(2_000_000_000).optional(),
    notes: z.array(z.string().max(500)).max(20).optional(),
    mandatory: z.boolean().optional(),
    minSupportedVersionCode: z.number().int().min(0).max(2_100_000_000).optional(),
    published: z.boolean().optional(),
  })
  .strict()

/** GET /admin/releases */
export const listReleases = asyncHandler(async (_req: Request, res: Response) => {
  const rows = await AppRelease.find().sort({ channel: 1, versionCode: -1 }).limit(100)
  successResponse(res, { items: rows.map(view) }, 'OK')
})

const problem = (d: z.infer<typeof releaseSchema>): string | null => {
  const url = checkDownloadUrl(d.downloadUrl)
  if (url) return url
  if ((d.minSupportedVersionCode ?? 0) > d.versionCode) {
    return 'The minimum supported version cannot be newer than this release.'
  }
  return null
}

/** POST /admin/releases */
export const createRelease = asyncHandler(async (req: Request, res: Response) => {
  const parsed = releaseSchema.safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'Please check the version (like 1.0.2), the version code (a whole number) and the other fields.', 400)
    return
  }
  const d = parsed.data
  const p = problem(d)
  if (p) {
    errorResponse(res, p, 400)
    return
  }
  if (await AppRelease.exists({ channel: d.channel, versionCode: d.versionCode })) {
    errorResponse(res, `Version code ${d.versionCode} already exists for this channel.`, 409)
    return
  }
  const row = await AppRelease.create({
    channel: d.channel,
    version: d.version,
    versionCode: d.versionCode,
    downloadUrl: d.downloadUrl,
    sha256: (d.sha256 ?? '').toLowerCase(),
    sizeBytes: d.sizeBytes ?? 0,
    notes: cleanNotes(d.notes ?? []),
    mandatory: d.mandatory ?? false,
    minSupportedVersionCode: d.minSupportedVersionCode ?? 0,
    published: d.published ?? false,
    releasedAt: d.published ? new Date() : null,
  })
  invalidate()
  await audit(req, 'release.create', { channel: d.channel, version: d.version, versionCode: d.versionCode, published: !!d.published })
  successResponse(res, view(row), d.published ? 'Release published — phones will see it within a minute.' : 'Release saved (not published yet).', 201)
})

/** PATCH /admin/releases/:id — same fields; publishing sets the release date. */
export const updateRelease = asyncHandler(async (req: Request, res: Response) => {
  const id = String(req.params['id'] ?? '')
  if (!mongoose.isValidObjectId(id)) {
    errorResponse(res, 'Release not found.', 404)
    return
  }
  const row = await AppRelease.findById(id)
  if (!row) {
    errorResponse(res, 'Release not found.', 404)
    return
  }
  const parsed = releaseSchema.partial().strict().safeParse(req.body)
  if (!parsed.success) {
    errorResponse(res, 'Please check the fields.', 400)
    return
  }
  const merged = {
    channel: parsed.data.channel ?? row.channel,
    version: parsed.data.version ?? row.version,
    versionCode: parsed.data.versionCode ?? row.versionCode,
    downloadUrl: parsed.data.downloadUrl ?? row.downloadUrl,
    minSupportedVersionCode: parsed.data.minSupportedVersionCode ?? row.minSupportedVersionCode,
  }
  const p = problem(merged)
  if (p) {
    errorResponse(res, p, 400)
    return
  }
  const clash = await AppRelease.exists({ _id: { $ne: row._id }, channel: merged.channel, versionCode: merged.versionCode })
  if (clash) {
    errorResponse(res, `Version code ${merged.versionCode} already exists for this channel.`, 409)
    return
  }
  const wasPublished = row.published
  row.set({
    ...parsed.data,
    ...(parsed.data.sha256 === undefined ? {} : { sha256: parsed.data.sha256.toLowerCase() }),
    ...(parsed.data.notes === undefined ? {} : { notes: cleanNotes(parsed.data.notes) }),
  })
  if (row.published && !wasPublished) row.releasedAt = new Date()
  await row.save()
  invalidate()
  await audit(req, 'release.update', { id, changed: Object.keys(parsed.data), published: row.published })
  successResponse(res, view(row), 'Saved.')
})
