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

const makeRedisStore = (prefix: string): RedisStore =>
  new RedisStore({
    sendCommand: async (...args: string[]) => {
      // noUncheckedIndexedAccess: guard args[0] before use
      const command = args[0]
      if (!command) return 0

      const result = await (redisConnection.call(
        command,
        ...args.slice(1),
      ) as Promise<unknown>)

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
  handler: rateLimitHandler,
})

export const authLimiter = rateLimit({
  // Silent token refresh (/auth/refresh) and logout are NOT brute-force
  // targets; counting them against the 10/15min budget used to log users out.
  skip: (req: Request) => req.path === '/refresh' || req.path === '/logout',
  windowMs: 15 * 60 * 1000,
  max: Number(process.env['RATE_LIMIT_MAX_AUTH'] ?? '10'),
  standardHeaders: true,
  legacyHeaders: false,
  store: makeRedisStore('rl:auth:'),
  handler: rateLimitHandler,
})

export const uploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: Number(process.env['RATE_LIMIT_MAX_UPLOAD'] ?? '20'),
  standardHeaders: true,
  legacyHeaders: false,
  store: makeRedisStore('rl:upload:'),
  handler: rateLimitHandler,
})

/** Admin API: generous for a human, stingy for a bot. */
export const adminLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number(process.env['RATE_LIMIT_MAX_ADMIN'] ?? '300'),
  standardHeaders: true,
  legacyHeaders: false,
  store: makeRedisStore('rl:admin:'),
  handler: rateLimitHandler,
})

/** Feature / sync endpoints used by the mobile app. */
export const syncLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number(process.env['RATE_LIMIT_MAX_SYNC'] ?? '600'),
  standardHeaders: true,
  legacyHeaders: false,
  store: makeRedisStore('rl:sync:'),
  handler: rateLimitHandler,
})
