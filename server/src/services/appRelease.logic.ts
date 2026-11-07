/**
 * Pure rules for app releases and the "update available" prompt (S2). No database, no Express.
 * Unit-tested in tests/app-release.test.mjs.
 */

export type ReleaseChannel = 'direct' | 'play'
export const CHANNELS: readonly ReleaseChannel[] = ['direct', 'play']

export interface ReleaseLike {
  channel: ReleaseChannel
  version: string
  versionCode: number
  downloadUrl: string
  sha256: string
  sizeBytes: number
  notes: string[]
  mandatory: boolean
  minSupportedVersionCode: number
  published: boolean
  releasedAt: Date | null
}

/** Hosts a download link may point to (https only). */
export const ALLOWED_DOWNLOAD_HOSTS = ['github.com', 'readin.micbol.org', 'play.google.com']

export const VERSION_RE = /^\d{1,3}\.\d{1,3}\.\d{1,3}$/

/** null = fine, otherwise a plain-language problem. */
export const checkDownloadUrl = (raw: string): string | null => {
  let u: URL
  try {
    u = new URL(raw)
  } catch {
    return 'The download link is not a valid web address.'
  }
  if (u.protocol !== 'https:') return 'The download link must start with https://'
  if (!ALLOWED_DOWNLOAD_HOSTS.includes(u.hostname)) {
    return `The download link must be on ${ALLOWED_DOWNLOAD_HOSTS.join(', ')}.`
  }
  return null
}

/** Release notes: trimmed, non-empty lines, at most 10 × 200 characters. */
export const cleanNotes = (notes: readonly string[]): string[] =>
  notes
    .map((n) => n.trim().slice(0, 200))
    .filter(Boolean)
    .slice(0, 10)

/** The newest published release of a channel (by versionCode). */
export const latestPublished = <T extends ReleaseLike>(releases: readonly T[], channel: ReleaseChannel): T | null =>
  releases
    .filter((r) => r.channel === channel && r.published)
    .sort((a, b) => b.versionCode - a.versionCode)[0] ?? null

export interface UpdateAnswer {
  updateAvailable: boolean
  mandatory: boolean
  latestVersion: string | null
  latestVersionCode: number | null
  minSupportedVersionCode: number
  downloadUrl: string | null
  sha256: string
  sizeBytes: number
  releaseNotes: string[]
  releasedAt: string | null
}

/**
 * What a phone running [currentCode] should do.
 * Mandatory when the phone is older than the minimum supported version, or the newest release is marked
 * mandatory (and the phone does not have it yet). Unknown current version (0) → never mandatory.
 */
export const decideUpdate = (latest: ReleaseLike | null, currentCode: number): UpdateAnswer => {
  if (!latest) {
    return {
      updateAvailable: false,
      mandatory: false,
      latestVersion: null,
      latestVersionCode: null,
      minSupportedVersionCode: 0,
      downloadUrl: null,
      sha256: '',
      sizeBytes: 0,
      releaseNotes: [],
      releasedAt: null,
    }
  }
  const known = currentCode > 0
  const newer = known && latest.versionCode > currentCode
  const tooOld = known && currentCode < latest.minSupportedVersionCode
  return {
    updateAvailable: newer,
    mandatory: newer && (tooOld || latest.mandatory),
    latestVersion: latest.version,
    latestVersionCode: latest.versionCode,
    minSupportedVersionCode: latest.minSupportedVersionCode,
    downloadUrl: latest.downloadUrl,
    sha256: latest.sha256,
    sizeBytes: latest.sizeBytes,
    releaseNotes: latest.notes,
    releasedAt: latest.releasedAt ? latest.releasedAt.toISOString() : null,
  }
}
