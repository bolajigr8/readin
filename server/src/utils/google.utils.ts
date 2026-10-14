/**
 * Verifies a Google ID token with Google (no extra npm package).
 * Set GOOGLE_CLIENT_ID to the WEB client id (several ids may be comma-separated).
 * Returns null when the token is invalid, expired, for another app, or the
 * e-mail is not verified — or when no client id is configured.
 */
export interface GoogleIdentity {
  sub: string
  email: string
  name: string
  picture: string
}

const allowedAudiences = (): string[] =>
  `${process.env['GOOGLE_CLIENT_ID'] ?? ''},${process.env['GOOGLE_CLIENT_IDS'] ?? ''}`
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)

export const verifyGoogleIdToken = async (idToken: string): Promise<GoogleIdentity | null> => {
  const audiences = allowedAudiences()
  if (audiences.length === 0) {
    console.error('[google] GOOGLE_CLIENT_ID is not configured — Google sign-in is refused.')
    return null
  }
  try {
    const res = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
      { signal: AbortSignal.timeout(8000) },
    )
    if (!res.ok) return null
    const p = (await res.json()) as Record<string, string | undefined>

    const aud = p['aud']
    const iss = p['iss']
    const exp = Number(p['exp'] ?? '0')
    const sub = p['sub']
    const email = p['email']
    if (!aud || !audiences.includes(aud)) return null
    if (iss !== 'accounts.google.com' && iss !== 'https://accounts.google.com') return null
    if (!Number.isFinite(exp) || exp * 1000 < Date.now()) return null
    if (String(p['email_verified']) !== 'true') return null
    if (!sub || !email) return null

    return { sub, email, name: p['name'] ?? '', picture: p['picture'] ?? '' }
  } catch {
    return null
  }
}
