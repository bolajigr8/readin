// Static checks for the website in project/site (no packages needed):  node tool/site_check.mjs
// - every page: lang, viewport, title, description; every internal link/image/script exists; every #anchor exists
// - nothing loaded from other websites (privacy + speed); only allowed outside links
// - legal pages contain what Google Play and the Data safety form need
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const site = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'site')
const failures = []
let checks = 0
const ok = (cond, msg) => {
  checks++
  if (!cond) failures.push(msg)
}

const SUPPORT = 'micboltech@gmail.com'
const WEB_DELETE = 'https://readin-ehzw.onrender.com/delete-account'
const ALLOWED_OUTSIDE = [/^mailto:micboltech@gmail\.com$/, /^https:\/\/readin\.micbol\.org(\/|$)/, new RegExp(`^${WEB_DELETE.replace(/[.]/g, '\\.')}$`)]

const pages = readdirSync(site).filter((f) => f.endsWith('.html'))
ok(pages.length >= 5, `expected at least 5 pages, found ${pages.length}`)
for (const must of ['index.html', 'privacy.html', 'terms.html', 'delete-account.html', '404.html']) {
  ok(pages.includes(must), `missing page ${must}`)
}
for (const forbidden of ['README.md', 'tests', 'node_modules', '.env']) {
  ok(!existsSync(path.join(site, forbidden)), `site/${forbidden} would be published — move it out of site/`)
}

/** "/privacy" → privacy.html, "/" → index.html, "/img/a.png" → img/a.png */
const resolveLocal = (href) => {
  const clean = href.split('#')[0].split('?')[0]
  if (clean === '/' || clean === '') return 'index.html'
  const rel = clean.replace(/^\//, '')
  if (existsSync(path.join(site, rel)) && statSync(path.join(site, rel)).isFile()) return rel
  if (existsSync(path.join(site, `${rel}.html`))) return `${rel}.html`
  return null
}

for (const page of pages) {
  const html = readFileSync(path.join(site, page), 'utf8')
  ok(/<html lang="en">/.test(html), `${page}: <html lang="en"> missing`)
  ok(/<meta name="viewport" content="width=device-width, initial-scale=1">/.test(html), `${page}: viewport meta missing`)
  ok(/<title>[^<]{5,}<\/title>/.test(html), `${page}: <title> missing`)
  if (page !== '404.html') ok(/<meta name="description" content="[^"]{20,}">/.test(html), `${page}: description missing`)
  const ids = new Set([...html.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1]))
  for (const m of html.matchAll(/\s(href|src)="([^"]+)"/g)) {
    const url = m[2]
    if (url.startsWith('#')) {
      ok(ids.has(url.slice(1)), `${page}: anchor ${url} has no matching id`)
    } else if (url.startsWith('/')) {
      ok(resolveLocal(url) !== null, `${page}: broken link ${url}`)
    } else {
      ok(ALLOWED_OUTSIDE.some((re) => re.test(url)), `${page}: outside link/resource not allowed: ${url}`)
    }
    if (m[1] === 'src') ok(!/^https?:/.test(url), `${page}: loads ${url} from another website`)
  }
  ok(!/<link[^>]+href="https?:\/\/(?!readin\.micbol\.org)/.test(html), `${page}: stylesheet/font from another website`)
}

const text = (f) => readFileSync(path.join(site, f), 'utf8')
const privacy = text('privacy.html')
for (const must of [SUPPORT, 'Paystack', 'Google Play', 'Render', 'MongoDB', 'Resend', 'Cloudinary', 'Upstash', 'delete-account', 'Nigeria Data Protection', 'children under 13', 'card details', 'Last updated']) {
  ok(privacy.includes(must), `privacy.html must mention "${must}"`)
}
const del = text('delete-account.html')
for (const must of [SUPPORT, WEB_DELETE, 'Profile', 'Delete account', 'Payment records', 'without your e-mail', 'ReadIn']) {
  ok(del.includes(must), `delete-account.html must mention "${must}"`)
}
const terms = text('terms.html')
for (const must of [SUPPORT, 'Google Play', 'Paystack', 'renews', 'Nigeria']) ok(terms.includes(must), `terms.html must mention "${must}"`)
for (const p of ['index.html', 'privacy.html', 'terms.html', 'delete-account.html']) {
  const h = text(p)
  for (const link of ['/privacy', '/delete-account']) ok(h.includes(`href="${link}"`) || p === `${link.slice(1)}.html`, `${p}: footer/nav link to ${link} missing`)
}

const rel = JSON.parse(text('release.json'))
ok(typeof rel.playUrl === 'string' && rel.apk && typeof rel.apk.url === 'string', 'release.json: needs playUrl and apk.url (strings)')
if (rel.apk.url) ok(/^https:\/\//.test(rel.apk.url) && /^[0-9a-f]{64}$/.test(rel.apk.sha256), 'release.json: apk.url must be https and sha256 must be filled')

const sitemap = text('sitemap.xml')
for (const m of sitemap.matchAll(/<loc>https:\/\/readin\.micbol\.org(\/[^<]*)<\/loc>/g)) {
  ok(resolveLocal(m[1]) !== null, `sitemap.xml lists ${m[1]} but no such page`)
}
ok(text('_headers').includes('Content-Security-Policy'), '_headers: security headers missing')

if (failures.length) {
  console.log(`site check: ${failures.length} problem(s) out of ${checks} checks`)
  for (const f of failures) console.log(`  ✗ ${f}`)
  process.exit(1)
}
console.log(`site check: ${checks} checks passed (${pages.length} pages)`)
