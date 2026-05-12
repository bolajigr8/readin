import IORedis from 'ioredis'

const getRedisUrl = (): string => {
  const url = process.env['UPSTASH_REDIS_URL']
  if (!url) throw new Error('UPSTASH_REDIS_URL is not configured')
  return url
}

/**
 * Factory — BullMQ requires a separate IORedis instance per Worker
 * because workers use blocking commands (BRPOP / BLPOP).
 * Call this once per Queue and once per Worker.
 */
export const createRedisConnection = (): IORedis => {
  return new IORedis(getRedisUrl(), {
    maxRetriesPerRequest: null, // required for BullMQ
    enableReadyCheck: false, // required for Upstash serverless Redis
  })
}

// Default connection — used by the Queue
export const redisConnection = createRedisConnection()
