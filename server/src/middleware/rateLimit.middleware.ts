import rateLimit, { ipKeyGenerator, type IncrementResponse } from 'express-rate-limit'
import { RedisStore } from 'rate-limit-redis'
import type { Request, Response } from 'express'
import { redisConnection } from '../config/redis.js'
import { clientIp } from '../utils/clientIp.js'

// ── Shared response handler ───────────────────────────────────────────────────

const rateLimitHandler = (_req: Request, res: Response): void => {
  res.status(429).json({
    success: false,
    message: 'Too many requests. Please try again later.',
  })
}

// ── Redis store factory ───────────────────────────────────────────────────────

/**
 * Rate limiting must never take the API down. A Redis command that takes longer
 * than this is treated as a failure, and (with `passOnStoreError`) the request
 * is simply let through instead of hanging or answering 500.
 */
const REDIS_TIMEOUT_MS = Number(process.env['REDIS_COMMAND_TIMEOUT_MS'] ?? '1500')

/** After a Redis failure, skip Redis entirely for a while (no waiting at all). */
const BREAKER_MS = Number(process.env['REDIS_BREAKER_MS'] ?? '20000')
let redisDownUntil = 0

const withTimeout = <T>(p: Promise<T>): Promise<T> =>
  new Promise<T>((resolve, reject) => {
    if (Date.now() < redisDownUntil) {
      p.catch(() => undefined) // the abandoned command may still fail later — ignore it
      reject(new Error('Redis unavailable (skipped)'))
      return
    }
    const t = setTimeout(() => {
      redisDownUntil = Date.now() + BREAKER_MS
      reject(new Error('Redis command timed out'))
    }, REDIS_TIMEOUT_MS)
    p.then(
      (v) => {
        clearTimeout(t)
        resolve(v)
      },
      (e: unknown) => {
        clearTimeout(t)
        redisDownUntil = Date.now() + BREAKER_MS
        reject(e instanceof Error ? e : new Error(String(e)))
      },
    )
  })

/**
 * Redis outage logging: ONE line when rate limiting pauses and one when it is back,
 * instead of a stack trace on every request (express-rate-limit logs each store error).
 */
let redisHealthy = true
const noteRedisFailure = (err: unknown): void => {
  redisDownUntil = Math.max(redisDownUntil, Date.now() + BREAKER_MS)
  if (!redisHealthy) return
  redisHealthy = false
  const msg = err instanceof Error ? err.message : String(err)
  console.warn(`[rate-limit] Redis unavailable (${msg}) — requests are allowed WITHOUT rate limits until it is back.`)
}
const noteRedisOk = (): void => {
  if (redisHealthy) return
  redisHealthy = true
  console.warn('[rate-limit] Redis is back — rate limits active again.')
}

/**
 * Startup grace: the TLS connection to Upstash can take a few seconds after boot. During that
 * time the limiters let requests through quietly instead of logging a false "Redis unavailable".
 */
const STARTUP_GRACE_MS = Number(process.env['REDIS_STARTUP_GRACE_MS'] ?? '10000')
const startedAt = Date.now()
const stillConnecting = (): boolean =>
  redisConnection.status !== 'ready' && Date.now() - startedAt < STARTUP_GRACE_MS

/** Resolves when Redis is ready, or when the startup grace is over (whichever comes first). */
const waitForStartup = (): Promise<void> =>
  new Promise<void>((resolve) => {
    if (!stillConnecting()) return resolve()
    const done = (): void => {
      clearTimeout(t)
      redisConnection.off('ready', done)
      resolve()
    }
    const t = setTimeout(done, Math.max(0, STARTUP_GRACE_MS - (Date.now() - startedAt)))
    redisConnection.once('ready', done)
  })

/** Counts as "first hit" → the request is allowed (fail open). Must be ≥ 1: express-rate-limit 8 rejects 0 (ERR_ERL_INVALID_HITS). */
const openResponse = (): IncrementResponse => ({ totalHits: 1, resetTime: undefined })

/** RedisStore that never throws: an unreachable Redis means "no rate limiting", never an outage. */
class FailOpenRedisStore extends RedisStore {
  override async init(options: Parameters<RedisStore['init']>[0]): Promise<void> {
    await waitForStartup()
    try {
      await super.init(options)
    } catch (err) {
      noteRedisFailure(err) // scripts are loaded again on the first increment
    }
  }

  override async increment(key: string): Promise<IncrementResponse> {
    if (stillConnecting() || Date.now() < redisDownUntil) return openResponse()
    try {
      const r = await super.increment(key)
      noteRedisOk()
      return r
    } catch (err) {
      noteRedisFailure(err)
      return openResponse()
    }
  }

  override async decrement(key: string): Promise<void> {
    if (stillConnecting() || Date.now() < redisDownUntil) return
    try {
      await super.decrement(key)
    } catch (err) {
      noteRedisFailure(err)
    }
  }

  override async resetKey(key: string): Promise<void> {
    if (stillConnecting() || Date.now() < redisDownUntil) return
    try {
      await super.resetKey(key)
    } catch (err) {
      noteRedisFailure(err)
    }
  }
}

const makeRedisStore = (prefix: string): RedisStore =>
  new FailOpenRedisStore({
    sendCommand: async (...args: string[]) => {
      // noUncheckedIndexedAccess: guard args[0] before use
      const command = args[0]
      if (!command) return 0

      const result = await withTimeout(
        redisConnection.call(command, ...args.slice(1)) as Promise<unknown>,
      )

      // RedisReply does not include null — coerce to 0 so types align
      if (result === null || result === undefined) return 0

      return result as number | string | string[]
    },
    prefix,
  })

/** One counter per real visitor (IPv6 grouped per /56 like the library default), not per proxy. */
const keyGenerator = (req: Request): string => ipKeyGenerator(clientIp(req))

// ── Limiters ──────────────────────────────────────────────────────────────────

export const generalLimiter = rateLimit({
  windowMs: Number(process.env['RATE_LIMIT_WINDOW_MS'] ?? '900000'),
  max: Number(process.env['RATE_LIMIT_MAX_GENERAL'] ?? '600'),
  keyGenerator,
  standardHeaders: true,
  legacyHeaders: false,
  store: makeRedisStore('rl:general:'),
  passOnStoreError: true, // Redis trouble = no rate limiting, never an outage
  handler: rateLimitHandler,
})

export const authLimiter = rateLimit({
  // Silent token refresh (/auth/refresh) and logout are NOT brute-force
  // targets; counting them against the 10/15min budget used to log users out.
  skip: (req: Request) => req.path === '/refresh' || req.path === '/logout',
  // Only FAILED attempts count: many phones share one mobile-network IP, and
  // successful sign-ins must not lock other people out.
  skipSuccessfulRequests: true,
  windowMs: 15 * 60 * 1000,
  max: Number(process.env['RATE_LIMIT_MAX_AUTH'] ?? '10'),
  keyGenerator,
  standardHeaders: true,
  legacyHeaders: false,
  store: makeRedisStore('rl:auth:'),
  passOnStoreError: true, // Redis trouble = no rate limiting, never an outage
  handler: rateLimitHandler,
})

export const uploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: Number(process.env['RATE_LIMIT_MAX_UPLOAD'] ?? '20'),
  keyGenerator,
  standardHeaders: true,
  legacyHeaders: false,
  store: makeRedisStore('rl:upload:'),
  passOnStoreError: true, // Redis trouble = no rate limiting, never an outage
  handler: rateLimitHandler,
})

/** Admin API: generous for a human, stingy for a bot. */
export const adminLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number(process.env['RATE_LIMIT_MAX_ADMIN'] ?? '300'),
  keyGenerator,
  standardHeaders: true,
  legacyHeaders: false,
  store: makeRedisStore('rl:admin:'),
  passOnStoreError: true, // Redis trouble = no rate limiting, never an outage
  handler: rateLimitHandler,
})

/** Feature / sync endpoints used by the mobile app. */
export const syncLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number(process.env['RATE_LIMIT_MAX_SYNC'] ?? '600'),
  keyGenerator,
  standardHeaders: true,
  legacyHeaders: false,
  store: makeRedisStore('rl:sync:'),
  passOnStoreError: true, // Redis trouble = no rate limiting, never an outage
  handler: rateLimitHandler,
})
