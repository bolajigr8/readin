// End-to-end tests for the ReadIn API (roadmap S0.4).
//
// Starts the REAL server (src/app.ts through tsx) as a child process against:
//   * an in-memory MongoDB (mongodb-memory-server — downloads mongod once, ~100 MB),
//   * a fake Paystack + fake Resend on 127.0.0.1 (PAYSTACK_BASE_URL / RESEND_BASE_URL),
//   * an UNREACHABLE Redis — so every test also proves the rate limiters fail open.
// The server never sees server/.env: DOTENV_CONFIG_PATH points at tests/e2e/e2e.env.
//
// Run:  pnpm run test:e2e
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { createHmac } from 'node:crypto'
import http from 'node:http'
import net from 'node:net'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { MongoMemoryServer } from 'mongodb-memory-server'
import mongoose from 'mongoose'

const here = path.dirname(fileURLToPath(import.meta.url))
const serverDir = path.resolve(here, '..', '..')

const PAYSTACK_KEY = 'sk_test_e2eFakeKeyOnly'
const ADMIN_EMAIL = 'admin@readin.test'
const PASSWORD = 'CorrectHorse9!'

// ── tiny runner (same output style as tests/*.test.mjs) ─────────────────────
let passed = 0
const failures = []
const test = async (name, fn) => {
  try {
    await fn()
    passed++
    console.log(`ok - ${name}`)
  } catch (err) {
    failures.push(name)
    console.log(`not ok - ${name}\n  ${err?.stack ?? err}`)
  }
}

const freePort = () =>
  new Promise((resolve, reject) => {
    const s = net.createServer()
    s.unref()
    s.on('error', reject)
    s.listen(0, '127.0.0.1', () => {
      const { port } = s.address()
      s.close(() => resolve(port))
    })
  })

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

// ── fake Paystack + fake Resend ──────────────────────────────────────────────
const mails = [] // { to, subject, html, text }
const tx = new Map() // reference → { amount, currency, status, reportAmount? }
let verifyCalls = 0
/** Simulates Paystack's firewall refusing POST requests from our server (HTML 403, like on Render 2026-11-06). */
let firewallBlocksPost = false

const readBody = (req) =>
  new Promise((resolve) => {
    let b = ''
    req.on('data', (c) => (b += c))
    req.on('end', () => resolve(b))
  })

const fake = http.createServer(async (req, res) => {
  const send = (code, obj) => {
    res.writeHead(code, { 'content-type': 'application/json' })
    res.end(JSON.stringify(obj))
  }
  const body = await readBody(req)
  const url = new URL(req.url, 'http://x')

  if (url.pathname === '/resend/emails' && req.method === 'POST') {
    const m = JSON.parse(body)
    mails.push({ to: [].concat(m.to)[0], subject: m.subject, html: m.html, text: m.text })
    return send(200, { id: `mail_${mails.length}` })
  }

  if (url.pathname.startsWith('/paystack/')) {
    if (firewallBlocksPost && req.method === 'POST') {
      res.writeHead(403, { 'content-type': 'text/html', 'cf-ray': '8f00test1234-LOS' })
      return res.end('<!DOCTYPE html><html><head><title>Attention Required! | Cloudflare</title></head><body>blocked</body></html>')
    }
    if (req.headers.authorization !== `Bearer ${PAYSTACK_KEY}`) return send(401, { status: false, message: 'Invalid key' })
    if (url.pathname === '/paystack/bank' && req.method === 'GET') {
      return send(200, { status: true, message: 'Banks retrieved', data: [{ name: 'Test Bank' }] })
    }
    if (url.pathname === '/paystack/transaction/initialize' && req.method === 'POST') {
      const j = JSON.parse(body)
      if (!(j.amount > 0)) return send(400, { status: false, message: 'Invalid Amount Sent' })
      tx.set(j.reference, { amount: j.amount, currency: j.currency, status: 'abandoned' })
      return send(200, {
        status: true,
        message: 'Authorization URL created',
        data: { authorization_url: `https://checkout.paystack.test/${j.reference}`, access_code: 'ac', reference: j.reference },
      })
    }
    const m = url.pathname.match(/^\/paystack\/transaction\/verify\/(.+)$/)
    if (m) {
      verifyCalls++
      const ref = decodeURIComponent(m[1])
      const t = tx.get(ref)
      if (!t) return send(404, { status: false, message: 'Transaction reference not found' })
      return send(200, {
        status: true,
        message: 'Verification successful',
        data: {
          id: 1,
          status: t.status,
          reference: ref,
          amount: t.reportAmount ?? t.amount,
          currency: t.currency,
          channel: 'card',
          paid_at: t.status === 'success' ? new Date().toISOString() : null,
          gateway_response: t.status === 'success' ? 'Approved' : 'Abandoned',
        },
      })
    }
  }
  send(404, { status: false, message: 'fake: unknown route' })
})

// ── start everything ─────────────────────────────────────────────────────────
console.log('# starting in-memory MongoDB (first run downloads it)…')
const mongo = await MongoMemoryServer.create()
const mongoUri = mongo.getUri('readin_e2e')
const fakePort = await freePort()
await new Promise((r) => fake.listen(fakePort, '127.0.0.1', r))
const apiPort = await freePort()
const deadRedisPort = await freePort() // nothing listens there
const ORIGIN = `http://127.0.0.1:${apiPort}`
const API = `${ORIGIN}/api/v1`

const keep = ['PATH', 'Path', 'SYSTEMROOT', 'SystemRoot', 'TEMP', 'TMP', 'HOME', 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'COMSPEC', 'PATHEXT']
const baseEnv = Object.fromEntries(keep.filter((k) => process.env[k] !== undefined).map((k) => [k, process.env[k]]))
const env = {
  ...baseEnv,
  DOTENV_CONFIG_PATH: path.join(here, 'e2e.env'),
  NODE_ENV: 'test',
  PORT: String(apiPort),
  MONGODB_URI: mongoUri,
  JWT_SECRET: 'e2e-access-secret-not-real-0123456789',
  JWT_REFRESH_SECRET: 'e2e-refresh-secret-not-real-0123456789',
  CLIENT_ORIGIN: ORIGIN,
  APP_URL: ORIGIN,
  RESEND_API_KEY: 're_e2e_fake',
  RESEND_BASE_URL: `http://127.0.0.1:${fakePort}/resend`,
  EMAIL_FROM: 'ReadIn <no-reply@readin.test>',
  PAYSTACK_SECRET_KEY: PAYSTACK_KEY,
  PAYSTACK_BASE_URL: `http://127.0.0.1:${fakePort}/paystack`,
  UPSTASH_REDIS_URL: `redis://127.0.0.1:${deadRedisPort}`,
  REDIS_COMMAND_TIMEOUT_MS: '300',
  ADMIN_EMAILS: ADMIN_EMAIL,
  CONVERSION_ENABLED: 'false',
  CLOUDINARY_CLOUD_NAME: 'e2e',
  CLOUDINARY_API_KEY: '000',
  CLOUDINARY_API_SECRET: 'e2e',
  TEMP_DIR: path.join(serverDir, 'tests', 'e2e', '.tmp'),
}

let serverLog = ''
const child = spawn(process.execPath, ['--import', 'tsx', 'src/app.ts'], { cwd: serverDir, env, stdio: ['ignore', 'pipe', 'pipe'] })
child.stdout.on('data', (d) => (serverLog += d))
child.stderr.on('data', (d) => (serverLog += d))

const shutdown = async () => {
  child.kill()
  fake.close()
  await mongoose.disconnect().catch(() => {})
  await mongo.stop().catch(() => {})
}

// ── HTTP helpers ─────────────────────────────────────────────────────────────
const call = async (method, p, { token, body, headers = {}, raw } = {}) => {
  const res = await fetch(p.startsWith('http') ? p : `${API}${p}`, {
    method,
    headers: {
      ...(body !== undefined || raw !== undefined ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    body: raw ?? (body === undefined ? undefined : JSON.stringify(body)),
    redirect: 'manual',
  })
  const text = await res.text()
  let json = null
  try {
    json = JSON.parse(text)
  } catch {
    /* HTML page */
  }
  return { status: res.status, json, text }
}

const lastMailTo = (email) => [...mails].reverse().find((m) => m.to === email)
/** The server sends e-mails in the background (after answering) — wait for the next one. */
const nextMailTo = async (email, after = mails.length, subject = /./) => {
  for (let i = 0; i < 100; i++) {
    const m = mails.slice(after).find((x) => x.to === email && subject.test(x.subject))
    if (m) return m
    await sleep(100)
  }
  throw new Error(`no e-mail to ${email} within 10 s`)
}
const tokenFrom = (mail, page) => {
  const m = `${mail.html} ${mail.text ?? ''}`.match(new RegExp(`/${page}\\?token=([^"'&\\s<]+)`))
  assert.ok(m, `no ${page} link in the e-mail "${mail.subject}"`)
  return decodeURIComponent(m[1])
}

const registerAndVerify = async (email, displayName = 'Reader') => {
  const before = mails.length
  const r = await call('POST', '/auth/register', { body: { email, password: PASSWORD, displayName } })
  assert.ok(r.status === 200 || r.status === 201, `register ${email}: ${r.status} ${r.text}`)
  const token = tokenFrom(await nextMailTo(email, before, /verif|confirm/i), 'verify-email')
  const v = await call('GET', `/auth/verify-email/${encodeURIComponent(token)}`)
  assert.equal(v.status, 200, `verify ${email}: ${v.text}`)
}

const login = async (email, password = PASSWORD) => {
  const r = await call('POST', '/auth/login', { body: { email, password } })
  assert.equal(r.status, 200, `login ${email}: ${r.status} ${r.text}`)
  return r.json.data.accessToken
}

const me = async (token) => {
  const r = await call('GET', '/users/me', { token })
  assert.equal(r.status, 200, r.text)
  return r.json.data.user ?? r.json.data
}

const signWebhook = (obj) => {
  const raw = JSON.stringify(obj)
  return { raw, sig: createHmac('sha512', PAYSTACK_KEY).update(raw).digest('hex') }
}

const DAY = 86_400_000

try {
  // wait for the server
  const t0 = Date.now()
  for (;;) {
    if (child.exitCode !== null) throw new Error(`server exited early:\n${serverLog}`)
    try {
      const h = await fetch(`${API}/health`)
      if (h.ok) break
    } catch {
      /* not up yet */
    }
    if (Date.now() - t0 > 60_000) throw new Error(`server did not start in 60 s:\n${serverLog}`)
    await sleep(250)
  }
  // the DB connects after listen — wait until a DB route answers
  for (let i = 0; i < 120; i++) {
    const r = await call('GET', '/config/public').catch(() => ({ status: 0 }))
    if (r.status === 200) break
    await sleep(250)
  }
  await mongoose.connect(mongoUri)
  const users = mongoose.connection.collection('users')
  const payments = mongoose.connection.collection('payments')

  // ── health / fail-open ─────────────────────────────────────────────────────
  await test('health answers 200 (no DB, no Redis needed)', async () => {
    const r = await call('GET', '/health')
    assert.equal(r.status, 200)
  })

  await test('Redis unreachable → the API still answers (rate limiters fail open)', async () => {
    for (let i = 0; i < 5; i++) {
      const r = await call('GET', '/config/public')
      assert.equal(r.status, 200)
    }
  })

  // ── accounts ───────────────────────────────────────────────────────────────
  const alice = 'alice@readin.test'
  await test('register sends a verification e-mail; login is refused until verified', async () => {
    const before = mails.length
    const r = await call('POST', '/auth/register', { body: { email: alice, password: PASSWORD, displayName: 'Alice' } })
    assert.ok(r.status === 200 || r.status === 201, r.text)
    const mail = await nextMailTo(alice, before)
    assert.ok(!JSON.stringify(r.json).includes(PASSWORD), 'password echoed back')
    const l = await call('POST', '/auth/login', { body: { email: alice, password: PASSWORD } })
    assert.equal(l.status, 403)
    assert.match(l.json.message, /verify/i)
  })

  await test('the e-mail link confirms the address; then login works', async () => {
    const token = tokenFrom(lastMailTo(alice), 'verify-email')
    const page = await call('GET', `${ORIGIN}/verify-email?token=${encodeURIComponent(token)}`, { headers: { accept: 'text/html' } })
    assert.equal(page.status, 200)
    assert.match(page.text, /<html/i)
    const v = await call('GET', `/auth/verify-email/${encodeURIComponent(token)}`)
    assert.ok([200, 400].includes(v.status), `verify api: ${v.status}`) // the page may already have used the token
    const u = await users.findOne({ email: alice })
    assert.equal(u.isEmailVerified, true)
    await login(alice)
  })

  await test('wrong password → 401, no token', async () => {
    const r = await call('POST', '/auth/login', { body: { email: alice, password: 'nope-nope-nope' } })
    assert.equal(r.status, 401)
    assert.equal(r.json?.data?.accessToken, undefined)
  })

  await test('forgot / reset password: e-mail link, new password works, old one does not', async () => {
    let before = mails.length
    const f = await call('POST', '/auth/forgot-password', { body: { email: alice } })
    assert.equal(f.status, 200)
    const token = tokenFrom(await nextMailTo(alice, before, /reset|password/i), 'reset-password')
    const r = await call('POST', '/auth/reset-password', { body: { token, password: 'NewPassword9!' } })
    assert.equal(r.status, 200, r.text)
    await login(alice, 'NewPassword9!')
    const old = await call('POST', '/auth/login', { body: { email: alice, password: PASSWORD } })
    assert.equal(old.status, 401)
    before = mails.length
    await call('POST', '/auth/forgot-password', { body: { email: alice } })
    const t2 = tokenFrom(await nextMailTo(alice, before, /reset|password/i), 'reset-password')
    await call('POST', '/auth/reset-password', { body: { token: t2, password: PASSWORD } })
  })

  await test('forgot-password for an unknown e-mail gives the same answer (no account fishing)', async () => {
    const before = mails.length
    const r = await call('POST', '/auth/forgot-password', { body: { email: 'nobody@readin.test' } })
    assert.equal(r.status, 200)
    await sleep(1500) // give a (wrong) background e-mail time to appear
    assert.equal(mails.filter((m) => m.to === 'nobody@readin.test').length, 0)
    assert.ok(mails.length >= before)
  })

  // ── admin ──────────────────────────────────────────────────────────────────
  let adminToken = ''
  let aliceToken = ''
  await test('admin API: normal user 403, admin (role in DB + ADMIN_EMAILS) 200', async () => {
    await registerAndVerify(ADMIN_EMAIL, 'Admin')
    await users.updateOne({ email: ADMIN_EMAIL }, { $set: { role: 'admin' } })
    adminToken = await login(ADMIN_EMAIL)
    aliceToken = await login(alice)
    assert.equal((await call('GET', '/admin/stats', { token: aliceToken })).status, 403)
    assert.equal((await call('GET', '/admin/stats', { token: adminToken })).status, 200)
    assert.equal((await call('GET', '/admin/stats')).status, 401)
  })

  await test('role "admin" but e-mail NOT in ADMIN_EMAILS → still 403 (second lock)', async () => {
    await users.updateOne({ email: alice }, { $set: { role: 'admin' } })
    const r = await call('GET', '/admin/stats', { token: aliceToken })
    await users.updateOne({ email: alice }, { $set: { role: 'user' } })
    assert.equal(r.status, 403)
  })

  await test('admin sets a plan and switches payments on → app sees it in /config/public', async () => {
    const r = await call('PUT', '/admin/billing', {
      token: adminToken,
      body: { enabled: true, plans: [{ name: 'Monthly', priceKobo: 150_000, durationDays: 30, active: true }] },
    })
    assert.equal(r.status, 200, r.text)
    let pub
    for (let i = 0; i < 20; i++) {
      pub = await call('GET', '/config/public')
      if (pub.json?.data?.billing?.enabled) break
      await sleep(250)
    }
    assert.equal(pub.json.data.billing.enabled, true)
    assert.equal(pub.json.data.billing.plans[0].priceKobo, 150_000)
  })

  // ── payments ───────────────────────────────────────────────────────────────
  const planId = async () => (await call('GET', '/config/public')).json.data.billing.plans[0].id
  const checkout = async (token) => {
    const r = await call('POST', '/payments/checkout', { token, body: { planId: await planId() } })
    assert.equal(r.status, 200, r.text)
    assert.match(r.json.data.authorizationUrl, /^https:\/\/checkout\.paystack\.test\//)
    return r.json.data.reference
  }

  await test('checkout: the price comes from the server, never from the app', async () => {
    const r = await call('POST', '/payments/checkout', { token: aliceToken, body: { planId: await planId(), priceKobo: 1 } })
    // extra fields are either rejected or ignored — but never used as the price
    if (r.status === 200) assert.equal(tx.get(r.json.data.reference).amount, 150_000)
    else assert.equal(r.status, 400)
  })

  await test('unpaid (abandoned) payment → no Premium', async () => {
    const ref = await checkout(aliceToken)
    const v = await call('GET', `/payments/verify/${ref}`, { token: aliceToken })
    assert.equal(v.status, 200)
    assert.notEqual(v.json.data.status, 'success')
    assert.equal((await me(aliceToken)).plan, 'free')
  })

  let firstUntil = 0
  await test('exactly once: verify + webhook + return page at the same time grant 30 days ONCE', async () => {
    const ref = await checkout(aliceToken)
    tx.get(ref).status = 'success'
    const hook = signWebhook({ event: 'charge.success', data: { reference: ref } })
    const results = await Promise.all([
      call('GET', `/payments/verify/${ref}`, { token: aliceToken }),
      call('POST', '/webhooks/paystack', { raw: hook.raw, headers: { 'x-paystack-signature': hook.sig } }),
      call('GET', `${ORIGIN}/payment/callback?reference=${ref}`, { headers: { accept: 'text/html' } }),
      call('GET', `/payments/verify/${ref}`, { token: aliceToken }),
    ])
    assert.equal(results[1].status, 200, results[1].text)
    const u = await users.findOne({ email: alice })
    assert.equal(u.plan, 'premium')
    const days = (new Date(u.premiumUntil).getTime() - Date.now()) / DAY
    assert.ok(days > 29.9 && days <= 30.01, `premium days = ${days} (should be 30, not 60/90/120)`)
    const p = await payments.findOne({ reference: ref })
    assert.equal(p.applied, true)
    assert.equal(p.status, 'success')
    firstUntil = new Date(u.premiumUntil).getTime()
  })

  await test('webhook with a bad signature → 401, nothing granted', async () => {
    const ref = await checkout(aliceToken)
    tx.get(ref).status = 'success'
    const hook = signWebhook({ event: 'charge.success', data: { reference: ref } })
    const r = await call('POST', '/webhooks/paystack', { raw: hook.raw, headers: { 'x-paystack-signature': 'f'.repeat(128) } })
    assert.equal(r.status, 401)
    const p = await payments.findOne({ reference: ref })
    assert.notEqual(p.applied, true)
    tx.get(ref).status = 'abandoned'
  })

  await test('amount mismatch (paid less than asked) → failed, Premium unchanged', async () => {
    const ref = await checkout(aliceToken)
    Object.assign(tx.get(ref), { status: 'success', reportAmount: 100 })
    const v = await call('GET', `/payments/verify/${ref}`, { token: aliceToken })
    assert.equal(v.json.data.status, 'failed')
    const u = await users.findOne({ email: alice })
    assert.equal(new Date(u.premiumUntil).getTime(), firstUntil)
  })

  await test('a second payment adds 30 days AFTER the time that is left', async () => {
    const ref = await checkout(aliceToken)
    tx.get(ref).status = 'success'
    const v = await call('GET', `/payments/verify/${ref}`, { token: aliceToken })
    assert.equal(v.json.data.status, 'success')
    const u = await users.findOne({ email: alice })
    const added = (new Date(u.premiumUntil).getTime() - firstUntil) / DAY
    assert.ok(Math.abs(added - 30) < 0.01, `added ${added} days`)
  })

  await test('someone else cannot verify my payment reference', async () => {
    const ref = await checkout(aliceToken)
    const bob = 'bob@readin.test'
    await registerAndVerify(bob, 'Bob')
    const bobToken = await login(bob)
    const r = await call('GET', `/payments/verify/${ref}`, { token: bobToken })
    assert.ok(r.status === 404 || r.status === 403, `got ${r.status}`)
  })

  await test('expired Premium is read as Free (date checked on every request)', async () => {
    await users.updateOne({ email: alice }, { $set: { premiumUntil: new Date(Date.now() - DAY) } })
    const u = await me(aliceToken)
    assert.equal(u.plan, 'free')
  })

  await test('the Google Play version can never start a Paystack payment (X-App-Distribution: play)', async () => {
    const before = tx.size
    const r = await call('POST', '/payments/checkout', {
      token: aliceToken,
      body: { planId: await planId() },
      headers: { 'x-app-distribution': 'play' },
    })
    assert.equal(r.status, 403, r.text)
    assert.match(r.json.message, /not available in this version/i)
    assert.equal(tx.size, before, 'Paystack must not be called')
    const direct = await call('POST', '/payments/checkout', {
      token: aliceToken,
      body: { planId: await planId() },
      headers: { 'x-app-distribution': 'direct' },
    })
    assert.equal(direct.status, 200, direct.text)
  })

  await test('admin "Test connection": key OK and "start payment" gets through → ok, nothing created', async () => {
    const before = tx.size
    const r = await call('POST', '/admin/billing/test', { token: adminToken, body: {} })
    assert.equal(r.status, 200, r.text)
    assert.equal(r.json.data.ok, true, r.text)
    assert.equal(tx.size, before, 'the probe must not create a transaction')
  })

  await test('Paystack firewall blocks "start payment": admin test says so (Ray ID), app gets a kind 502', async () => {
    firewallBlocksPost = true
    try {
      const t = await call('POST', '/admin/billing/test', { token: adminToken, body: {} })
      assert.equal(t.status, 200, t.text)
      assert.equal(t.json.data.ok, false, 'admin test must NOT say "working" when payments are blocked')
      assert.match(t.json.data.message, /firewall/i)
      assert.match(t.json.data.detail, /8f00test1234-LOS/)
      const c = await call('POST', '/payments/checkout', { token: aliceToken, body: { planId: await planId() } })
      assert.equal(c.status, 502)
      assert.match(c.json.message, /temporarily unavailable/i)
      assert.match(serverLog, /initialize failed:.*Ray ID 8f00test1234-LOS/)
    } finally {
      firewallBlocksPost = false
    }
  })

  await test('Redis down is logged once, not on every request', async () => {
    const n = (serverLog.match(/\[rate-limit\] Redis unavailable/g) ?? []).length
    assert.ok(n >= 1 && n <= 3, `expected 1-3 "[rate-limit] Redis unavailable" lines, got ${n}`)
    assert.ok(!serverLog.includes('express-rate-limit: error from store'), 'express-rate-limit still logs every store error')
    assert.ok(!serverLog.includes('ERR_ERL_INVALID_HITS'), 'fail-open store returned 0 hits (express-rate-limit 8 rejects that)')
    assert.ok(!serverLog.includes('Unhandled error event'), 'ioredis error events are not handled')
  })

  await test('payments switched off in admin → checkout refused, app told to hide payments', async () => {
    const r = await call('PUT', '/admin/billing', { token: adminToken, body: { enabled: false } })
    assert.equal(r.status, 200, r.text)
    let pub
    for (let i = 0; i < 80; i++) {
      pub = await call('GET', '/config/public')
      if (pub.json?.data?.billing?.enabled === false) break
      await sleep(250)
    }
    assert.equal(pub.json.data.billing.enabled, false)
    const c = await call('POST', '/payments/checkout', { token: aliceToken, body: { planId: 'anything' } })
    assert.notEqual(c.status, 200)
  })

  await test('every admin change is written to the audit log', async () => {
    const r = await call('GET', '/admin/audit', { token: adminToken })
    assert.equal(r.status, 200)
    assert.ok(JSON.stringify(r.json).match(/billing/i), 'no billing entry in the audit log')
  })

  await test('no e-mail contains a password or a Paystack key', async () => {
    for (const m of mails) {
      const s = JSON.stringify(m)
      assert.ok(!s.includes(PASSWORD) && !s.includes('NewPassword9!'), `password in "${m.subject}"`)
      assert.ok(!s.includes(PAYSTACK_KEY), `key in "${m.subject}"`)
    }
  })

  // ── S7.1 account deletion ────────────────────────────────────────────────────
  const db = mongoose.connection
  const seedUserData = async (email) => {
    const u = await users.findOne({ email })
    const userId = u._id
    const bookId = new mongoose.Types.ObjectId()
    await db.collection('books').insertOne({ _id: bookId, userId, title: `Book of ${email}`, status: 'ready', source: 'upload' })
    await db.collection('annotations').insertOne({ userId, bookId, text: 'note' })
    await db.collection('bookmarks').insertOne({ userId, bookId, cfi: 'x' })
    await db.collection('progresses').insertOne({ userId, bookId, percentage: 10 })
    await db.collection('userdatas').insertOne({ userId, key: 'habits', data: {}, version: 1 })
    await db.collection('userfeatures').insertOne({ userId, key: 'habits', trialStartedAt: new Date() })
    await db.collection('payments').insertOne({ userId, email, planId: 'monthly', planName: 'Monthly', reference: `ref_${userId}`, amountKobo: 150000, currency: 'NGN', durationDays: 30, status: 'success', applied: true })
    return userId
  }
  const countFor = async (userId) => {
    const names = ['books', 'annotations', 'bookmarks', 'progresses', 'userdatas', 'userfeatures']
    const counts = await Promise.all(names.map((n) => db.collection(n).countDocuments({ userId })))
    return Object.fromEntries(names.map((n, i) => [n, counts[i]]))
  }

  await test('delete my account in the app: wrong password refused; right password removes everything, keeps an anonymous payment', async () => {
    const dave = 'dave@readin.test'
    const erin = 'erin@readin.test'
    await registerAndVerify(dave, 'Dave')
    await registerAndVerify(erin, 'Erin')
    const daveId = await seedUserData(dave)
    const erinId = await seedUserData(erin)
    const token = await login(dave)

    const wrong = await call('DELETE', '/users/me', { token, body: { password: 'not-my-password' } })
    assert.equal(wrong.status, 403, wrong.text)
    assert.match(wrong.json.message, /password is not correct/i)
    assert.equal((await countFor(daveId)).books, 1, 'nothing may be deleted after a wrong password')

    const before = mails.length
    const ok = await call('DELETE', '/users/me', { token, body: { password: PASSWORD } })
    assert.equal(ok.status, 200, ok.text)
    assert.deepEqual(Object.values(await countFor(daveId)), [0, 0, 0, 0, 0, 0], 'all of Dave’s data must be gone')
    assert.equal(await users.countDocuments({ email: dave }), 0, 'the account must be gone')
    const pay = await payments.findOne({ userId: daveId })
    assert.ok(pay, 'the payment record is kept for accounting')
    assert.equal(pay.email, '', 'but without the e-mail address')
    assert.deepEqual(Object.values(await countFor(erinId)), [1, 1, 1, 1, 1, 1], 'another user’s data must be untouched')
    assert.equal((await payments.findOne({ userId: erinId })).email, erin)

    assert.equal((await call('GET', '/users/me', { token })).status, 401, 'the old sign-in must stop working at once')
    assert.equal((await call('POST', '/auth/login', { body: { email: dave, password: PASSWORD } })).status, 401)
    const bye = await nextMailTo(dave, before, /deleted/i)
    assert.match(bye.subject, /was deleted/i)
    const audit = await db.collection('adminaudits').findOne({ action: 'account.deleted_by_user', targetUserId: daveId })
    assert.ok(audit, 'an audit line is written')
    assert.ok(!JSON.stringify(audit).includes(dave), 'the audit line holds no e-mail address')
  })

  await test('delete my account on the web: same answer for unknown e-mails; link → page → button deletes; link works once', async () => {
    const frank = 'frank@readin.test'
    await registerAndVerify(frank, 'Frank')
    const frankId = await seedUserData(frank)

    const unknown = await call('POST', '/auth/delete-account/request', { body: { email: 'nobody@readin.test' } })
    const known0 = mails.length
    const known = await call('POST', '/auth/delete-account/request', { body: { email: frank } })
    assert.equal(unknown.status, 200)
    assert.equal(known.status, 200)
    assert.equal(unknown.json.message, known.json.message, 'no account fishing')

    const link = tokenFrom(await nextMailTo(frank, known0, /delete/i), 'delete-account/confirm')
    const page = await call('GET', `${ORIGIN}/delete-account/confirm?token=${encodeURIComponent(link)}`, { headers: { accept: 'text/html' } })
    assert.equal(page.status, 200)
    assert.match(page.text, /Delete your account for good/)
    assert.equal(await users.countDocuments({ email: frank }), 1, 'opening the page alone deletes nothing')

    const bad = await call('POST', '/auth/delete-account/confirm', { body: { token: 'x'.repeat(64) } })
    assert.equal(bad.status, 400)
    const badPage = await call('GET', `${ORIGIN}/delete-account/confirm?token=nope`, { headers: { accept: 'text/html' } })
    assert.equal(badPage.status, 400)

    const done = await call('POST', '/auth/delete-account/confirm', { body: { token: link } })
    assert.equal(done.status, 200, done.text)
    assert.equal(await users.countDocuments({ email: frank }), 0)
    assert.equal((await countFor(frankId)).books, 0)
    assert.equal((await call('POST', '/auth/delete-account/confirm', { body: { token: link } })).status, 400, 'the link works only once')

    const form = await call('GET', `${ORIGIN}/delete-account`, { headers: { accept: 'text/html' } })
    assert.equal(form.status, 200)
    assert.match(form.text, /Delete your ReadIn account/)
  })

  await test('an expired web deletion link deletes nothing', async () => {
    const gina = 'gina@readin.test'
    await registerAndVerify(gina, 'Gina')
    const m0 = mails.length
    await call('POST', '/auth/delete-account/request', { body: { email: gina } })
    const link = tokenFrom(await nextMailTo(gina, m0, /delete/i), 'delete-account/confirm')
    await users.updateOne({ email: gina }, { $set: { accountDeletionExpires: new Date(Date.now() - 1000) } })
    const r = await call('POST', '/auth/delete-account/confirm', { body: { token: link } })
    assert.equal(r.status, 400)
    assert.equal(await users.countDocuments({ email: gina }), 1)
  })

  await test('the server log never prints the Paystack key or JWT secrets', async () => {
    assert.ok(!serverLog.includes(PAYSTACK_KEY))
    assert.ok(!serverLog.includes(env.JWT_SECRET) && !serverLog.includes(env.JWT_REFRESH_SECRET))
  })

  console.log(`# Paystack verify calls: ${verifyCalls}, e-mails sent: ${mails.length}`)
} catch (err) {
  failures.push('setup')
  console.log(`not ok - setup\n  ${err?.stack ?? err}`)
} finally {
  await shutdown()
}

if (failures.length) {
  console.log(`\n${passed} tests passed, ${failures.length} failed: ${failures.join(' | ')}`)
  console.log('--- server log (last 3000 chars) ---\n' + serverLog.slice(-3000))
  process.exit(1)
}
console.log(`\n${passed} tests passed`)
process.exit(0)
