import rateLimit from 'express-rate-limit'
import { RedisStore } from 'rate-limit-redis'
import type { Request, Response } from 'express'
import { redisConnection } from '../config/redis.js'

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

const makeRedisStore = (prefix: string): RedisStore =>
  new RedisStore({
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

// ── Limiters ──────────────────────────────────────────────────────────────────

export const generalLimiter = rateLimit({
  windowMs: Number(process.env['RATE_LIMIT_WINDOW_MS'] ?? '900000'),
  max: Number(process.env['RATE_LIMIT_MAX_GENERAL'] ?? '600'),
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
  standardHeaders: true,
  legacyHeaders: false,
  store: makeRedisStore('rl:auth:'),
  passOnStoreError: true, // Redis trouble = no rate limiting, never an outage
  handler: rateLimitHandler,
})

export const uploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: Number(process.env['RATE_LIMIT_MAX_UPLOAD'] ?? '20'),
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
  standardHeaders: true,
  legacyHeaders: false,
  store: makeRedisStore('rl:sync:'),
  passOnStoreError: true, // Redis trouble = no rate limiting, never an outage
  handler: rateLimitHandler,
})
