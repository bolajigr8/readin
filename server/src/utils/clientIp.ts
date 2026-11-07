import { isIP } from 'node:net'
import type { Request } from 'express'

/**
 * The visitor's real IP address.
 *
 * On Render the API sits behind Cloudflare + Render's load balancer, so `req.ip` (trust proxy = 1) is one of
 * several proxy addresses — many users then share one rate-limit counter. Cloudflare puts the real address in
 * `CF-Connecting-IP` (and overwrites any value a client sends), so in production we prefer that header.
 * Outside production (local, tests) headers are ignored: anyone could fake them there.
 */
export type IpSource = 'cf-connecting-ip' | 'true-client-ip' | 'req.ip'

const header = (req: Pick<Request, 'headers'>, name: string): string => {
  const v = req.headers[name]
  const s = (Array.isArray(v) ? v[0] : v) ?? ''
  return s.trim()
}

export const resolveClientIp = (
  req: Pick<Request, 'headers' | 'ip'>,
  production: boolean,
): { ip: string; source: IpSource } => {
  if (production) {
    for (const name of ['cf-connecting-ip', 'true-client-ip'] as const) {
      const v = header(req, name)
      if (v && isIP(v)) return { ip: v, source: name }
    }
  }
  return { ip: req.ip ?? '', source: 'req.ip' }
}

let loggedSource: IpSource | null = null

/** Real client IP for rate limits and the audit log. Logs once which source is used (never the address). */
export const clientIp = (req: Pick<Request, 'headers' | 'ip'>): string => {
  const { ip, source } = resolveClientIp(req, process.env['NODE_ENV'] === 'production')
  if (loggedSource !== source) {
    loggedSource = source
    console.log(`[client-ip] using ${source} for rate limits and audit`)
  }
  return ip
}
