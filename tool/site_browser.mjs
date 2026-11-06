// Opens every page of project/site in the installed Edge (or Chrome) at phone size:   node tool/site_browser.mjs
// Serves the folder like Cloudflare Pages does (clean URLs, the _headers security rules incl. CSP) and checks:
// no console/page errors, no failed requests, no sideways scrolling at 360 px, light + dark mode,
// and that release.json really switches the download buttons on.
// Uses playwright-core from mobile/tool/reader_harness (run `pnpm install` there once; no browser download).
import http from 'node:http'
import { readFileSync, existsSync, statSync } from 'node:fs'
import path from 'node:path'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const site = path.join(root, 'site', 'out') // the static export (`pnpm build` in project/site)
if (!existsSync(path.join(site, 'index.html'))) {
  console.log('project/site/out is missing — run `pnpm build` in project/site first.')
  process.exit(1)
}
const require = createRequire(path.join(root, 'mobile', 'tool', 'reader_harness', 'package.json'))
const { chromium } = require('playwright-core')

// The "/*" block of _headers → applied to every response (so CSP problems show up here too).
const headers = {}
let inAll = false
for (const line of readFileSync(path.join(site, '_headers'), 'utf8').split(/\r?\n/)) {
  if (/^\S/.test(line)) inAll = line.trim() === '/*'
  else if (inAll && line.includes(':')) {
    const i = line.indexOf(':')
    headers[line.slice(0, i).trim()] = line.slice(i + 1).trim()
  }
}
delete headers['Strict-Transport-Security'] // local http

const TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.xml': 'application/xml', '.txt': 'text/plain', '.woff2': 'font/woff2', '.ico': 'image/x-icon', '.svg': 'image/svg+xml' }
let releaseOverride = null
const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x').pathname
  if (url === '/release.json' && releaseOverride) {
    res.writeHead(200, { ...headers, 'content-type': TYPES['.json'] })
    return res.end(JSON.stringify(releaseOverride))
  }
  let file = url === '/' ? 'index.html' : url.slice(1)
  // Like Cloudflare Pages: /privacy → privacy.html (Next also writes a privacy/ folder with data files).
  const isFile = (f) => existsSync(path.join(site, f)) && statSync(path.join(site, f)).isFile()
  if (!isFile(file) && isFile(`${file}.html`)) file = `${file}.html`
  const full = path.join(site, file)
  if (!full.startsWith(site) || !existsSync(full) || !statSync(full).isFile()) {
    res.writeHead(404, { ...headers, 'content-type': TYPES['.html'] })
    return res.end(readFileSync(path.join(site, '404.html')))
  }
  res.writeHead(200, { ...headers, 'content-type': TYPES[path.extname(full)] ?? 'application/octet-stream' })
  res.end(readFileSync(full))
})
await new Promise((r) => server.listen(0, '127.0.0.1', r))
const BASE = `http://127.0.0.1:${server.address().port}`

let browser
for (const channel of ['msedge', 'chrome']) {
  try {
    browser = await chromium.launch({ channel, headless: true })
    console.log(`# browser: ${channel} ${browser.version()}`)
    break
  } catch {
    /* try the next one */
  }
}
if (!browser) {
  console.log('No Edge or Chrome found — install one, or skip this check.')
  process.exit(1)
}

const failures = []
let passed = 0
const test = async (name, fn) => {
  try {
    await fn()
    passed++
    console.log(`ok - ${name}`)
  } catch (e) {
    failures.push(name)
    console.log(`not ok - ${name}\n  ${String(e?.message ?? e).split('\n')[0]}`)
  }
}

const visit = async (pathName, colorScheme) => {
  const ctx = await browser.newContext({ viewport: { width: 360, height: 740 }, colorScheme, deviceScaleFactor: 2 })
  const page = await ctx.newPage()
  const problems = []
  page.on('console', (m) => {
    if (m.type() === 'error') problems.push(`console: ${m.text()}`)
  })
  page.on('pageerror', (e) => problems.push(`page error: ${e.message}`))
  page.on('requestfailed', (r) => problems.push(`failed: ${r.url()}`))
  page.on('response', (r) => {
    if (r.status() >= 400 && !r.url().endsWith(pathName)) problems.push(`HTTP ${r.status()}: ${r.url()}`)
  })
  const res = await page.goto(BASE + pathName, { waitUntil: 'networkidle' })
  const wide = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)
  return { ctx, page, res, problems, wide }
}

for (const p of ['/', '/privacy', '/terms', '/delete-account']) {
  for (const scheme of ['light', 'dark']) {
    await test(`${p} (${scheme}): loads, no errors, no sideways scroll at 360 px`, async () => {
      const v = await visit(p, scheme)
      try {
        if (v.res.status() !== 200) throw new Error(`HTTP ${v.res.status()}`)
        if (v.problems.length) throw new Error(v.problems.join(' | '))
        if (v.wide > 1) throw new Error(`page is ${v.wide}px wider than the phone screen`)
        const h1 = await v.page.locator('h1').first().textContent()
        if (!h1 || h1.trim().length < 5) throw new Error('no heading')
        // SITE_SHOTS=<folder> → also save a phone screenshot of each page (for a visual check).
        if (process.env.SITE_SHOTS) {
          const name = `${p === '/' ? 'home' : p.slice(1)}-${scheme}.png`
          // scroll through the page so the fade-in sections appear, then back to the top
          await v.page.evaluate(async () => {
            for (let y = 0; y < document.body.scrollHeight; y += 300) {
              window.scrollTo({ top: y, behavior: 'instant' })
              await new Promise((r) => setTimeout(r, 60))
            }
            window.scrollTo({ top: 0, behavior: 'instant' })
          })
          await v.page.waitForTimeout(900)
          await v.page.screenshot({ path: path.join(process.env.SITE_SHOTS, name), fullPage: true })
          if (p === '/') {
            await v.page.setViewportSize({ width: 1280, height: 860 })
            await v.page.waitForTimeout(400)
            await v.page.screenshot({ path: path.join(process.env.SITE_SHOTS, `home-desktop-${scheme}.png`) })
          }
        }
      } finally {
        await v.ctx.close()
      }
    })
  }
}

await test('clicking footer links really opens the pages (home → privacy → delete-account → home)', async () => {
  const v = await visit('/', 'light')
  try {
    await v.page.locator('footer a', { hasText: 'Privacy policy' }).click()
    await v.page.waitForURL('**/privacy', { timeout: 10000 })
    await v.page.locator('h1', { hasText: 'Privacy policy' }).waitFor({ timeout: 10000 })
    await v.page.locator('footer a', { hasText: 'Delete my account' }).click()
    await v.page.waitForURL('**/delete-account', { timeout: 10000 })
    await v.page.locator('h1', { hasText: 'Delete your ReadIn account' }).waitFor({ timeout: 10000 })
    await v.page.locator('header a', { hasText: 'ReadIn' }).first().click()
    await v.page.locator('h1', { hasText: 'Fall in love with' }).waitFor({ timeout: 10000 })
    await v.page.waitForLoadState('networkidle')
    if (v.problems.length) throw new Error(v.problems.join(' | '))
  } finally {
    await v.ctx.close()
  }
})

await test('the light/dark switch changes the theme and remembers it', async () => {
  const v = await visit('/', 'light')
  try {
    const isDark = () => v.page.evaluate(() => document.documentElement.classList.contains('dark'))
    if (await isDark()) throw new Error('should start light (phone setting = light)')
    await v.page.getByRole('button', { name: /dark mode/i }).click()
    if (!(await isDark())) throw new Error('did not switch to dark')
    await v.page.reload({ waitUntil: 'networkidle' })
    if (!(await isDark())) throw new Error('choice not remembered after reload')
  } finally {
    await v.ctx.close()
  }
})

await test('unknown address shows the 404 page', async () => {
  const v = await visit('/no-such-page', 'light')
  try {
    if (v.res.status() !== 404) throw new Error(`HTTP ${v.res.status()}`)
    if (!(await v.page.content()).includes('This page does not exist')) throw new Error('not the 404 page')
  } finally {
    await v.ctx.close()
  }
})

await test('no release yet → both buttons say "coming soon" and are not clickable', async () => {
  releaseOverride = { playUrl: '', apk: { url: '', version: '', date: '', sizeMb: 0, sha256: '' } }
  const v = await visit('/', 'light')
  try {
    for (const id of ['#play-btn', '#apk-btn']) {
      const b = v.page.locator(id)
      if ((await b.getAttribute('aria-disabled')) !== 'true') throw new Error(`${id} is clickable`)
      if (!/coming soon/i.test(await b.textContent())) throw new Error(`${id} text: ${await b.textContent()}`)
    }
  } finally {
    await v.ctx.close()
  }
})

await test('the published release.json: APK button works, Play still "coming soon" until the Play link is added', async () => {
  releaseOverride = null // the real file in out/
  const rel = JSON.parse(readFileSync(path.join(site, 'release.json'), 'utf8'))
  const v = await visit('/', 'light')
  try {
    const apk = v.page.locator('#apk-btn')
    if (rel.apk.url) {
      if (!/^https:\/\/github\.com\/bolajigr8\/readin-releases\/releases\/download\//.test(rel.apk.url)) throw new Error('APK URL is not a readin-releases download')
      if (!/^[0-9a-f]{64}$/.test(rel.apk.sha256)) throw new Error('sha256 is not 64 hex characters')
      if ((await apk.getAttribute('href')) !== rel.apk.url) throw new Error('APK link not set')
    }
    if (!rel.playUrl && (await v.page.locator('#play-btn').getAttribute('aria-disabled')) !== 'true') throw new Error('Play button clickable without a link')
  } finally {
    await v.ctx.close()
  }
})

await test('release.json filled → real Play + download links, version, size and SHA-256 shown', async () => {
  releaseOverride = {
    playUrl: 'https://play.google.com/store/apps/details?id=com.micbol.readin',
    apk: { url: 'https://example.org/readin-1.0.0-arm64-v8a.apk', version: '1.0.0', date: '2026-11-06', sizeMb: 33.1, sha256: 'a'.repeat(64) },
  }
  const v = await visit('/', 'light')
  try {
    const play = v.page.locator('#play-btn')
    const apk = v.page.locator('#apk-btn')
    if ((await play.getAttribute('href')) !== releaseOverride.playUrl) throw new Error('Play link not set')
    if ((await play.getAttribute('aria-disabled')) !== null) throw new Error('Play button still disabled')
    if ((await apk.getAttribute('href')) !== releaseOverride.apk.url) throw new Error('APK link not set')
    if (!/v1\.0\.0/.test(await apk.textContent())) throw new Error('version not shown')
    const note = await v.page.locator('#release-note').textContent()
    if (!note.includes('33.1 MB') || !note.includes('a'.repeat(64))) throw new Error(`note: ${note}`)
  } finally {
    releaseOverride = null
    await v.ctx.close()
  }
})

await browser.close()
server.close()
console.log(failures.length ? `\n${passed} passed, ${failures.length} failed` : `\n${passed} tests passed`)
process.exit(failures.length ? 1 : 0)
