import rateLimit from 'express-rate-limit'
import type { Request, Response } from 'express'
import RedisStore from 'rate-limit-redis'
import type { RedisReply } from 'rate-limit-redis' // ← import the type
import { redisConnection } from '../config/redis'

// ── Shared rate limit response handler ────────────────────────────────────────

const rateLimitHandler = (_req: Request, res: Response): void => {
  res.status(429).json({
    success: false,
    message: 'Too many requests. Please try again later.',
  })
}

// ── Limiters ──────────────────────────────────────────────────────────────────

export const generalLimiter = rateLimit({
  windowMs: Number(process.env['RATE_LIMIT_WINDOW_MS'] ?? '900000'),
  max: Number(process.env['RATE_LIMIT_MAX_GENERAL'] ?? '200'),
  standardHeaders: true,
  legacyHeaders: false,
  handler: rateLimitHandler,
})

export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number(process.env['RATE_LIMIT_MAX_AUTH'] ?? '10'),
  standardHeaders: true,
  legacyHeaders: false,
  store: new RedisStore({
    sendCommand: (command: string, ...args: string[]) =>
      redisConnection.call(command, ...args) as Promise<RedisReply>, // ← cast to RedisReply
  }),
  handler: rateLimitHandler,
})

export const uploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: Number(process.env['RATE_LIMIT_MAX_UPLOAD'] ?? '20'),
  standardHeaders: true,
  legacyHeaders: false,
  handler: rateLimitHandler,
})
