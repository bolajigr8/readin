// Browser test for assets/reader/reader.html (roadmap S0.5).
//
// Serves reader.html exactly like the app's ReaderServer does (same URL layout:
// /<token>/reader.html, /<token>/book.bin, /<token>/fonts/*.woff2, config injected
// into __READIN_CONFIG__), with a small EPUB generated here whose OWN stylesheet
// fights our settings (line-height, font, colours). Then it drives the page in the
// Microsoft Edge / Chrome already installed on this PC (playwright-core, no download)
// and measures what the reader really shows.
//
// Run whenever assets/reader/reader.html changes:
//   cd mobile/tool/reader_harness && pnpm install && pnpm test
import assert from 'node:assert/strict'
import http from 'node:http'
import { createRequire } from 'node:module'
import { readFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium } from 'playwright-core'

const here = path.dirname(fileURLToPath(import.meta.url))
const readerDir = path.resolve(here, '..', '..', 'assets', 'reader')
const require = createRequire(import.meta.url)
const JSZip = require(path.join(readerDir, 'jszip.min.js')) // the same JSZip the reader ships

// ── tiny runner ──────────────────────────────────────────────────────────────
let passed = 0
const failures = []
const test = async (name, fn) => {
  try {
    await fn()
    passed++
    console.log(`ok - ${name}`)
  } catch (err) {
    failures.push(name)
    console.log(`not ok - ${name}\n  ${err?.message ?? err}`)
  }
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

// ── test EPUB (2 long chapters; the book's CSS tries to override us) ─────────
const para = (c, i) =>
  `<p>Chapter ${c}, paragraph ${i}. The quick brown fox jumps over the lazy dog while the reader keeps ` +
  `turning pages, one after another, to see that <b>bold words</b> and <i>italic words</i> keep their look.</p>`
const chapter = (c) => `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter ${c}</title>
<link rel="stylesheet" type="text/css" href="book.css"/></head>
<body><h1 id="c${c}">Chapter ${c}</h1>${Array.from({ length: 60 }, (_, i) => para(c, i + 1)).join('\n')}</body></html>`

const makeEpub = async () => {
  const z = new JSZip()
  z.file('mimetype', 'application/epub+zip', { compression: 'STORE' })
  z.file('META-INF/container.xml', `<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
<rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>`)
  z.file('OEBPS/content.opf', `<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">readin-harness</dc:identifier>
<dc:title>Harness Book</dc:title><dc:language>en</dc:language><meta property="dcterms:modified">2026-11-05T00:00:00Z</meta></metadata>
<manifest>
<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
<item id="css" href="book.css" media-type="text/css"/>
<item id="c1" href="c1.xhtml" media-type="application/xhtml+xml"/>
<item id="c2" href="c2.xhtml" media-type="application/xhtml+xml"/>
</manifest>
<spine><itemref idref="c1"/><itemref idref="c2"/></spine></package>`)
  z.file('OEBPS/nav.xhtml', `<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Contents</title></head>
<body><nav epub:type="toc"><ol><li><a href="c1.xhtml">Chapter 1</a></li><li><a href="c2.xhtml">Chapter 2</a></li></ol></nav></body></html>`)
  // The book's own rules — the reader's settings must win over every one of them.
  z.file('OEBPS/book.css', `p { line-height: 1.1; font-family: "Courier New", monospace; color: #00ff00; font-weight: 300; text-align: right; }
body { background: #123456; }`)
  z.file('OEBPS/c1.xhtml', chapter(1))
  z.file('OEBPS/c2.xhtml', chapter(2))
  return z.generateAsync({ type: 'nodebuffer', mimeType: 'application/epub+zip' })
}

// ── a server that behaves like ReaderServer (lib/features/reader/data/reader_server.dart) ──
const TOKEN = 'a1b2c3d4e5f60718293a4b5c6d7e8f90'
const startServer = async (book, config) => {
  const server = http.createServer(async (req, res) => {
    const segs = new URL(req.url, 'http://x').pathname.split('/').filter(Boolean)
    const isFont = segs.length === 3 && segs[1] === 'fonts' && /^[a-z0-9-]{1,60}\.woff2$/.test(segs[2])
    if (req.method !== 'GET' || segs[0] !== TOKEN || !(segs.length === 2 || isFont)) {
      res.writeHead(404).end()
      return
    }
    try {
      if (isFont) {
        res.writeHead(200, { 'content-type': 'font/woff2' }).end(await readFile(path.join(readerDir, 'fonts', segs[2])))
        return
      }
      switch (segs[1]) {
        case 'reader.html': {
          // READER_HTML lets a check run against a modified copy (used to prove the tests can fail)
          const html = await readFile(process.env.READER_HTML || path.join(readerDir, 'reader.html'), 'utf8')
          const cfg = JSON.stringify({ ...config, bookUrl: 'book.bin' }).replaceAll('<', '\\u003c')
          res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }).end(html.replace('__READIN_CONFIG__', cfg))
          return
        }
        case 'jszip.min.js':
        case 'epub.min.js':
          res.writeHead(200, { 'content-type': 'application/javascript; charset=utf-8' })
          res.end(await readFile(path.join(readerDir, segs[1])))
          return
        case 'book.bin':
          res.writeHead(200, { 'content-type': 'application/octet-stream' }).end(book)
          return
        default:
          res.writeHead(404).end()
      }
    } catch {
      res.writeHead(500).end()
    }
  })
  await new Promise((r) => server.listen(0, '127.0.0.1', r))
  return { server, url: `http://127.0.0.1:${server.address().port}/${TOKEN}/reader.html` }
}

// ── browser ──────────────────────────────────────────────────────────────────
const launch = async () => {
  for (const channel of ['msedge', 'chrome']) {
    try {
      return { browser: await chromium.launch({ channel, headless: true }), channel }
    } catch {
      /* try the next one */
    }
  }
  throw new Error('Neither Microsoft Edge nor Google Chrome could be started. Install one of them.')
}

const SETTINGS = {
  fontSize: 18,
  fontFamily: 'sans-serif',
  fontWeight: 400,
  theme: 'dark',
  lineHeight: 1.5,
  margin: 16,
  align: 'left',
  hyphenate: true,
  flow: 'paged',
  pageAnim: 'slide',
}

const openReader = async (browser, book, config) => {
  const { server, url } = await startServer(book, config)
  const page = await browser.newPage({ viewport: { width: 412, height: 860 }, deviceScaleFactor: 1 })
  await page.addInitScript(() => {
    window.__msgs = []
    window.ReadIn = { postMessage: (s) => window.__msgs.push(JSON.parse(s)) }
  })
  const pageErrors = []
  page.on('pageerror', (e) => pageErrors.push(String(e)))
  await page.goto(url)
  await page.waitForFunction(() => window.__msgs.some((m) => m.type === 'BOOK_READY' || m.type === 'ERROR'), null, { timeout: 30_000 })
  const close = async () => {
    await page.close()
    server.close()
  }
  return { page, close, pageErrors }
}

const msgs = (page) => page.evaluate(() => window.__msgs)
const bookFrame = (page) => page.frames().find((f) => f !== page.mainFrame())

/** Applies settings the way the app does (readerApi.setTheme(json)) and waits for the relayout. */
const setTheme = async (page, p) => {
  await page.evaluate((json) => window.readerApi.setTheme(json), JSON.stringify(p))
  await sleep(400) // scheduleRelayout waits 120 ms, then epub.js re-renders
}

/** Computed style of the first <p> (and of <b>, <body>) inside the book iframe. */
const styles = async (page) => {
  const f = bookFrame(page)
  return f.evaluate(() => {
    const p = document.querySelector('p')
    const b = document.querySelector('b')
    const cs = getComputedStyle(p)
    const body = getComputedStyle(document.body)
    return {
      fontFamily: cs.fontFamily,
      fontSize: cs.fontSize,
      lineHeight: cs.lineHeight,
      fontWeight: cs.fontWeight,
      color: cs.color,
      textAlign: cs.textAlign,
      bWeight: getComputedStyle(b).fontWeight,
      bodyBg: body.backgroundColor,
      bodyPadLeft: body.paddingLeft,
    }
  })
}

const FAMILY_NAMES = {
  literata: 'Literata',
  merriweather: 'Merriweather',
  lora: 'Lora',
  lexend: 'Lexend',
  atkinson: 'Atkinson Hyperlegible',
  opendyslexic: 'OpenDyslexic',
}

// ── run ──────────────────────────────────────────────────────────────────────
const book = await makeEpub()
const { browser, channel } = await launch()
console.log(`# browser: ${channel} ${browser.version()}`)

try {
  const r = await openReader(browser, book, SETTINGS)
  const { page } = r

  await test('the book opens (BOOK_READY), no errors', async () => {
    const m = await msgs(page)
    assert.ok(m.some((x) => x.type === 'BOOK_READY'), JSON.stringify(m))
    assert.deepEqual(m.filter((x) => x.type === 'ERROR'), [])
    assert.deepEqual(r.pageErrors, [])
    assert.ok(bookFrame(page), 'no book iframe')
  })

  await test('settings beat the book\'s own CSS (size, line-height, colour, alignment, weight)', async () => {
    await setTheme(page, { ...SETTINGS, fontSize: 20, lineHeight: 2, align: 'justify', fontWeight: 400 })
    const s = await styles(page)
    assert.equal(s.fontSize, '20px')
    assert.equal(s.lineHeight, '40px') // book says 1.1
    assert.equal(s.color, 'rgb(228, 228, 231)') // dark theme text, book says green
    assert.equal(s.textAlign, 'justify') // book says right
    assert.equal(s.fontWeight, '400') // book says 300
  })

  await test('bold setting: text 700, <b> stays heavier (900)', async () => {
    await setTheme(page, { ...SETTINGS, fontWeight: 700 })
    const s = await styles(page)
    assert.equal(s.fontWeight, '700')
    assert.equal(s.bWeight, '900')
  })

  await test('themes change the page colours (sepia)', async () => {
    await setTheme(page, { ...SETTINGS, theme: 'sepia' })
    const s = await styles(page)
    assert.equal(s.bodyBg, 'rgb(240, 222, 198)')
    assert.equal(s.color, 'rgb(18, 18, 18)')
    const outer = await page.evaluate(() => getComputedStyle(document.getElementById('viewer')).backgroundColor)
    assert.equal(outer, 'rgb(240, 222, 198)')
  })

  for (const [key, family] of Object.entries(FAMILY_NAMES)) {
    await test(`font "${key}" is applied AND its bundled file really loads (offline)`, async () => {
      await setTheme(page, { ...SETTINGS, fontFamily: key })
      const f = bookFrame(page)
      const s = await styles(page)
      assert.ok(s.fontFamily.includes(family), `font-family = ${s.fontFamily}`)
      const loaded = await f.evaluate(async (fam) => {
        await document.fonts.load(`400 16px "${fam}"`)
        await document.fonts.ready
        return document.fonts.check(`400 16px "${fam}"`) &&
          [...document.fonts].some((ff) => ff.family.replace(/"/g, '') === fam && ff.status === 'loaded')
      }, family)
      assert.ok(loaded, `${family} did not load from /fonts/`)
    })
  }

  await test('margins: paged mode uses the epub.js gap (padding = margin on each side)', async () => {
    for (const margin of [8, 32]) {
      await setTheme(page, { ...SETTINGS, margin })
      const s = await styles(page)
      assert.equal(s.bodyPadLeft, `${margin}px`, `margin ${margin}`)
    }
  })

  const location = async () => (await msgs(page)).filter((x) => x.type === 'LOCATION').at(-1)
  const turnAndWait = async (dir) => {
    const before = (await msgs(page)).filter((x) => x.type === 'LOCATION').length
    await page.evaluate((d) => (d > 0 ? window.readerApi.next() : window.readerApi.prev()), dir)
    await page.waitForFunction((n) => window.__msgs.filter((x) => x.type === 'LOCATION').length > n, before, { timeout: 5000 })
    await sleep(80)
  }

  await test('page turn with the slide animation moves smoothly in one direction and lands on a page', async () => {
    await setTheme(page, { ...SETTINGS })
    await page.evaluate(() => window.readerApi.display('c1.xhtml'))
    await sleep(500)
    const res = await page.evaluate(
      () =>
        new Promise((resolve) => {
          const c = document.querySelector('.epub-container')
          const xs = []
          const start = c.scrollLeft
          const t0 = performance.now()
          const tick = () => {
            xs.push(c.scrollLeft)
            if (performance.now() - t0 < 700) requestAnimationFrame(tick)
            else resolve({ xs, start, end: c.scrollLeft, width: c.offsetWidth })
          }
          window.readerApi.next()
          requestAnimationFrame(tick)
        }),
    )
    const steps = new Set(res.xs).size
    assert.ok(steps >= 5, `only ${steps} distinct positions — no visible slide`)
    for (let i = 1; i < res.xs.length; i++) assert.ok(res.xs[i] >= res.xs[i - 1], 'slide went backwards')
    assert.ok(Math.abs(res.end - res.start - res.width) <= 2, `moved ${res.end - res.start}, page is ${res.width}`)
  })

  await test('slide and instant turns end on the same pages; back returns to the start', async () => {
    await page.evaluate(() => window.readerApi.display('c1.xhtml'))
    await sleep(500)
    const start = (await location()).cfi
    const slide = []
    for (let i = 0; i < 4; i++) {
      await turnAndWait(1)
      await sleep(320)
      slide.push((await location()).cfi)
    }
    await page.evaluate(() => window.readerApi.setPageAnim('none'))
    await page.evaluate(() => window.readerApi.display('c1.xhtml'))
    await sleep(500)
    const instant = []
    for (let i = 0; i < 4; i++) {
      await turnAndWait(1)
      instant.push((await location()).cfi)
    }
    assert.deepEqual(instant, slide)
    for (let i = 0; i < 4; i++) await turnAndWait(-1)
    assert.equal((await location()).cfi, start)
    await page.evaluate(() => window.readerApi.setPageAnim('slide'))
  })

  await test('turning pages crosses from chapter 1 into chapter 2', async () => {
    await page.evaluate(() => window.readerApi.setPageAnim('none'))
    await page.evaluate(() => window.readerApi.display('c1.xhtml'))
    await sleep(500)
    let loc = await location()
    for (let i = 0; i < 200 && !String(loc.href).endsWith('c2.xhtml'); i++) {
      await turnAndWait(1)
      loc = await location()
    }
    assert.ok(String(loc.href).endsWith('c2.xhtml'), `still in ${loc.href}`)
    await turnAndWait(-1)
    assert.ok(String((await location()).href).endsWith('c1.xhtml'), 'back did not return to chapter 1')
  })

  await test('still no errors after all of the above', async () => {
    assert.deepEqual((await msgs(page)).filter((x) => x.type === 'ERROR'), [])
    assert.deepEqual(r.pageErrors, [])
  })
  await r.close()

  // scroll mode: margins are CSS padding there
  const s = await openReader(browser, book, { ...SETTINGS, flow: 'scroll', margin: 24 })
  await test('scroll mode opens and uses CSS padding for the margin', async () => {
    assert.ok((await msgs(s.page)).some((x) => x.type === 'BOOK_READY'))
    const st = await styles(s.page)
    assert.equal(st.bodyPadLeft, '24px')
  })
  await s.close()

  // a broken saved position must not make the book unopenable
  const bad = await openReader(browser, book, { ...SETTINGS, initialCfi: 'epubcfi(/6/999!/4/2/1:0)' })
  await test('a stale saved position still opens the book', async () => {
    assert.ok((await msgs(bad.page)).some((x) => x.type === 'BOOK_READY'))
  })
  await bad.close()
} finally {
  await browser.close()
}

if (failures.length) {
  console.log(`\n${passed} tests passed, ${failures.length} failed`)
  process.exit(1)
}
console.log(`\n${passed} tests passed`)
