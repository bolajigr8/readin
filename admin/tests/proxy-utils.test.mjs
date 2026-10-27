// Run: node --experimental-strip-types tests/proxy-utils.test.mjs   (Node 22+)
import assert from 'node:assert/strict'
import {
  targetPath, isSameOrigin, isTrustedRequest, cookieOptions, apiBase, messageFrom,
} from '../src/lib/proxy-utils.ts'

let n = 0
const t = (name, fn) => { fn(); n++; console.log('ok -', name) }
const id = 'a'.repeat(24)

t('allows exactly the admin API paths', () => {
  for (const p of ['stats', 'audit', 'config', 'config/features/habits', 'billing', 'payments', `users/${id}/verify`, 'users', `users/${id}`,
    `users/${id}/features/habits/grant`, `users/${id}/features/habits/reset-trial`]) {
    assert.equal(targetPath('/api/admin/' + p, 'GET'), p, p)
  }
  assert.equal(targetPath('/api/admin/users/', 'GET'), 'users') // trailing slash
})

t('rejects traversal, encoded slashes, unknown routes and bad ids', () => {
  for (const p of ['../auth/login', 'users/../stats', 'users//x', 'users%2Fx', 'users\\x', 'nope',
    'users/123', `users/${id}/features/habits/delete`, `users/${id}/extra`, 'config/features/HABITS', '']) {
    assert.equal(targetPath('/api/admin/' + p, 'GET'), null, p)
  }
  assert.equal(targetPath('/api/other/stats', 'GET'), null)
})

t('methods: GET/POST/PUT/PATCH only', () => {
  assert.equal(targetPath('/api/admin/stats', 'DELETE'), null)
  assert.equal(targetPath('/api/admin/stats', 'OPTIONS'), null)
  assert.equal(targetPath('/api/admin/stats', 'patch'), 'stats')
})

t('origin check (CSRF): writes need same origin AND the custom header', () => {
  assert.equal(isSameOrigin('https://admin.example.com', 'admin.example.com'), true)
  assert.equal(isSameOrigin('https://evil.com', 'admin.example.com'), false)
  assert.equal(isSameOrigin(null, 'admin.example.com'), false)
  assert.equal(isSameOrigin('not a url', 'admin.example.com'), false)
  assert.equal(isTrustedRequest('GET', null, null, null), true)
  assert.equal(isTrustedRequest('POST', 'https://a.com', 'a.com', 'admin'), true)
  assert.equal(isTrustedRequest('POST', 'https://a.com', 'a.com', null), false)
  assert.equal(isTrustedRequest('PUT', 'https://evil.com', 'a.com', 'admin'), false)
})

t('cookie options are httpOnly + SameSite=strict, secure in production', () => {
  const o = cookieOptions(60, true)
  assert.deepEqual(o, { httpOnly: true, secure: true, sameSite: 'strict', path: '/', maxAge: 60 })
  assert.equal(cookieOptions(60, false).secure, false)
})

t('apiBase validates and trims', () => {
  assert.equal(apiBase('https://x.onrender.com/api/v1/'), 'https://x.onrender.com/api/v1')
  assert.equal(apiBase('  http://localhost:5000/api/v1 '), 'http://localhost:5000/api/v1')
  assert.equal(apiBase(''), null)
  assert.equal(apiBase(undefined), null)
  assert.equal(apiBase('ftp://x'), null)
  assert.equal(apiBase('javascript:alert(1)'), null)
})

t('messageFrom never passes through odd bodies', () => {
  assert.equal(messageFrom({ message: 'Nope.' }, 'x'), 'Nope.')
  assert.equal(messageFrom('<html>', 'fallback'), 'fallback')
  assert.equal(messageFrom({ message: 'a'.repeat(400) }, 'fallback'), 'fallback')
  assert.equal(messageFrom(null, 'fallback'), 'fallback')
})
console.log(`\n${n} tests passed`)
