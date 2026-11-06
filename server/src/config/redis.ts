import IORedis from 'ioredis'
import { cleanRedisUrl, describeRedisUrl } from './redis.url.js'

const getRedisUrl = (): string => {
  const url = process.env['UPSTASH_REDIS_URL']
  if (!url) throw new Error('UPSTASH_REDIS_URL is not configured')
  return cleanRedisUrl(url)
}

let described = false

/**
 * Factory — BullMQ requires a separate IORedis instance per Worker
 * because workers use blocking commands (BRPOP / BLPOP).
 * Call this once per Queue and once per Worker.
 */
export const createRedisConnection = (): IORedis => {
  const url = getRedisUrl()
  const info = describeRedisUrl(url)
  if (!described) {
    described = true
    console.log(`[redis] connecting to ${info.safe}`) // never the password
    if (info.warning) console.warn(`[redis] ${info.warning}`)
  }

  const conn = new IORedis(url, {
    maxRetriesPerRequest: null, // required for BullMQ
    enableReadyCheck: false, // required for Upstash serverless Redis
    // Upstash only speaks TLS — force it even if the URL says redis://
    ...(info.tls ? { tls: {} } : {}),
  })

  // Without an 'error' listener ioredis prints "Unhandled error event" + a stack on every
  // reconnect attempt. Log one short line per distinct error instead (ioredis keeps retrying).
  let lastError = ''
  conn.on('error', (err: Error) => {
    const msg = err.message
    if (msg === lastError) return
    lastError = msg
    console.warn(`[redis] connection problem: ${msg}`)
  })
  conn.on('ready', () => {
    if (lastError) console.log('[redis] connected again')
    else console.log('[redis] connected')
    lastError = ''
  })
  return conn
}

// Default connection — used by the Queue
export const redisConnection = createRedisConnection()
