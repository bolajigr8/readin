// Run:  node --experimental-strip-types tests/redis-url.test.mjs   (Node 22+)
import assert from 'node:assert/strict'
import { describeRedisUrl, cleanRedisUrl } from '../src/config/redis.url.ts'

let n = 0
const t = (name, fn) => { fn(); n++; console.log('ok -', name) }

t('rediss:// Upstash URL → TLS, no warning, password hidden', () => {
  const r = describeRedisUrl('rediss://default:SECRETpw@fine-cat-123.upstash.io:6379')
  assert.equal(r.tls, true); assert.equal(r.warning, null)
  assert.equal(r.safe, 'rediss://fine-cat-123.upstash.io:6379 (TLS)')
  assert.ok(!r.safe.includes('SECRET'))
})
t('redis:// (one s) Upstash URL → TLS forced + warning', () => {
  const r = describeRedisUrl('redis://default:pw@fine-cat-123.upstash.io:6379')
  assert.equal(r.tls, true); assert.match(r.warning, /two s/)
})
t('REST URL (https://) → clear warning', () => {
  const r = describeRedisUrl('https://fine-cat-123.upstash.io')
  assert.match(r.warning, /REST URL/)
})
t('missing password → warning', () => {
  assert.match(describeRedisUrl('rediss://fine-cat-123.upstash.io:6379').warning, /no password/)
})
t('garbage → warning, nothing leaked', () => {
  const r = describeRedisUrl('not a url secret'); assert.equal(r.safe, '(unreadable URL)'); assert.ok(r.warning)
})
t('local redis:// stays plain TCP without a warning', () => {
  const r = describeRedisUrl('redis://:pw@localhost:6379'); assert.equal(r.tls, false); assert.equal(r.warning, null)
})
t('quotes/spaces from copy-paste are removed', () => {
  assert.equal(cleanRedisUrl('  "rediss://default:pw@x.upstash.io:6379" '), 'rediss://default:pw@x.upstash.io:6379')
  assert.equal(describeRedisUrl('"rediss://default:pw@x.upstash.io:6379"').warning, null)
})
console.log(`\n${n} tests passed`)
