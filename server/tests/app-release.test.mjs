// Run:  node --experimental-strip-types tests/app-release.test.mjs   (Node 22+)
// S2 — "update available" rules (pure).
import assert from 'node:assert/strict'
import { checkDownloadUrl, cleanNotes, decideUpdate, latestPublished } from '../src/services/appRelease.logic.ts'

let n = 0
const t = (name, fn) => { fn(); n++; console.log('ok -', name) }
const rel = (o = {}) => ({
  channel: 'direct', version: '1.0.2', versionCode: 3, downloadUrl: 'https://github.com/bolajigr8/readin-releases/releases/download/v1.0.2/readin-1.0.2-universal.apk',
  sha256: 'a'.repeat(64), sizeBytes: 90_000_000, notes: ['Faster reader'], mandatory: false, minSupportedVersionCode: 0,
  published: true, releasedAt: new Date('2026-11-10T10:00:00Z'), ...o,
})

t('no release → nothing to do', () => {
  const a = decideUpdate(null, 2)
  assert.equal(a.updateAvailable, false); assert.equal(a.mandatory, false); assert.equal(a.downloadUrl, null)
})
t('newer release → optional update with link, size, checksum and notes', () => {
  const a = decideUpdate(rel(), 2)
  assert.deepEqual([a.updateAvailable, a.mandatory, a.latestVersion, a.latestVersionCode], [true, false, '1.0.2', 3])
  assert.equal(a.sizeBytes, 90_000_000); assert.deepEqual(a.releaseNotes, ['Faster reader'])
  assert.equal(a.releasedAt, '2026-11-10T10:00:00.000Z')
})
t('same or newer phone → no update', () => {
  assert.equal(decideUpdate(rel(), 3).updateAvailable, false)
  assert.equal(decideUpdate(rel(), 4).updateAvailable, false)
})
t('release marked mandatory → mandatory for older phones only', () => {
  assert.equal(decideUpdate(rel({ mandatory: true }), 2).mandatory, true)
  assert.equal(decideUpdate(rel({ mandatory: true }), 3).mandatory, false)
})
t('phone older than the minimum supported version → mandatory', () => {
  assert.equal(decideUpdate(rel({ minSupportedVersionCode: 3 }), 2).mandatory, true)
  assert.equal(decideUpdate(rel({ minSupportedVersionCode: 2 }), 2).mandatory, false)
})
t('unknown phone version (0) → never an update prompt, never blocked', () => {
  const a = decideUpdate(rel({ mandatory: true, minSupportedVersionCode: 3 }), 0)
  assert.equal(a.updateAvailable, false); assert.equal(a.mandatory, false)
})
t('latest published per channel; unpublished ignored', () => {
  const rows = [rel({ versionCode: 3 }), rel({ versionCode: 5, published: false }), rel({ versionCode: 4 }), rel({ channel: 'play', versionCode: 9 })]
  assert.equal(latestPublished(rows, 'direct').versionCode, 4)
  assert.equal(latestPublished(rows, 'play').versionCode, 9)
  assert.equal(latestPublished([], 'play'), null)
})
t('download links: https + allowed hosts only', () => {
  assert.equal(checkDownloadUrl('https://github.com/bolajigr8/readin-releases/releases/download/v1/a.apk'), null)
  assert.equal(checkDownloadUrl('https://play.google.com/store/apps/details?id=com.micbol.readin'), null)
  assert.equal(checkDownloadUrl('https://readin.micbol.org/'), null)
  assert.match(checkDownloadUrl('http://github.com/x.apk'), /https/)
  assert.match(checkDownloadUrl('https://evil.example/x.apk'), /must be on/)
  assert.match(checkDownloadUrl('https://github.com.evil.example/x.apk'), /must be on/)
  assert.match(checkDownloadUrl('not a url'), /not a valid/)
})
t('notes: trimmed, empty lines dropped, max 10 × 200 chars', () => {
  assert.deepEqual(cleanNotes(['  a  ', '', '   ', 'b']), ['a', 'b'])
  assert.equal(cleanNotes(Array.from({ length: 15 }, (_, i) => `n${i}`)).length, 10)
  assert.equal(cleanNotes(['x'.repeat(300)])[0].length, 200)
})
console.log(`\n${n} tests passed`)
