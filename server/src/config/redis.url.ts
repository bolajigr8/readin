/**
 * Pure helpers for the Redis connection (no network, safe to unit-test).
 *
 * Upstash only accepts TLS connections. A URL that starts with `redis://` (one "s")
 * makes ioredis talk plain TCP, Upstash closes the socket, and the logs fill with
 * `read ECONNRESET` while every command times out. We switch TLS on for Upstash
 * hosts no matter how the URL was written, and tell the owner to fix the variable.
 */

export interface RedisUrlInfo {
  /** Options to pass to ioredis next to the URL. */
  tls: boolean
  /** Safe to log: scheme, host and port only — never the password. */
  safe: string
  /** A plain-language problem with the URL, or null. */
  warning: string | null
}

export const describeRedisUrl = (raw: string): RedisUrlInfo => {
  const url = cleanRedisUrl(raw)
  let u: URL
  try {
    u = new URL(url)
  } catch {
    return {
      tls: false,
      safe: '(unreadable URL)',
      warning:
        'UPSTASH_REDIS_URL is not a valid URL. It must look like rediss://default:<password>@<host>.upstash.io:6379',
    }
  }
  const scheme = u.protocol.replace(':', '')
  const isUpstash = u.hostname.endsWith('.upstash.io')
  const tls = scheme === 'rediss' || isUpstash
  const port = u.port || '6379'
  const safe = `${scheme}://${u.hostname}:${port}${tls ? ' (TLS)' : ''}`

  let warning: string | null = null
  if (scheme !== 'redis' && scheme !== 'rediss') {
    warning = `UPSTASH_REDIS_URL starts with "${scheme}://" — it must start with rediss:// (use the Redis/TCP URL from Upstash, not the REST URL).`
  } else if (isUpstash && scheme === 'redis') {
    warning = 'UPSTASH_REDIS_URL starts with redis:// — Upstash needs rediss:// (two s). TLS is switched on automatically, but please fix the variable on Render.'
  } else if (!u.password) {
    warning = 'UPSTASH_REDIS_URL has no password in it (expected rediss://default:<password>@<host>:6379).'
  }
  return { tls, safe, warning }
}

/** The URL with surrounding quotes/spaces removed (a common copy-paste mistake). */
export const cleanRedisUrl = (raw: string): string => raw.trim().replace(/^["']|["']$/g, '')
