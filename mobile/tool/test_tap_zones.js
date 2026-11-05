// Runs the reader's real tap-zone helpers (extracted from reader.html) in Node.
const fs = require('fs'), assert = require('assert')
const html = fs.readFileSync(__dirname + '/../assets/reader/reader.html', 'utf8')
const m = html.match(/function tapX\(e\)[\s\S]*?function tapZone\(x, width\)[\s\S]*?\n  \}\n/)
assert(m, 'tap helpers not found in reader.html')
const { tapX, tapZone } = new Function(m[0] + '; return { tapX, tapZone }')()
const W = 400
const ev = (clientX, frameLeft) => ({ clientX, view: { frameElement: { getBoundingClientRect: () => ({ left: frameLeft }) } } })
let n = 0
const t = (name, fn) => { fn(); n++; console.log('ok -', name) }

t('page 1: left / middle / right', () => {
  assert.equal(tapZone(tapX(ev(40, 0)), W), 'prev')
  assert.equal(tapZone(tapX(ev(200, 0)), W), 'menu')
  assert.equal(tapZone(tapX(ev(370, 0)), W), 'next')
})
t('page 5 (iframe scrolled 4 screens left): the SAME screen taps give the SAME zones', () => {
  const off = -4 * W
  assert.equal(tapZone(tapX(ev(4 * W + 40, off)), W), 'prev')
  assert.equal(tapZone(tapX(ev(4 * W + 200, off)), W), 'menu')   // was wrongly "next" before the fix
  assert.equal(tapZone(tapX(ev(4 * W + 370, off)), W), 'next')
})
t('no frame element (scroll mode / odd events) still works', () => {
  assert.equal(tapX({ clientX: 123 }), 123)
  assert.equal(tapX({}), 0)
  assert.equal(tapZone(tapX({ clientX: 200, view: {} }), W), 'menu')
})
t('zone borders: 25 % and 75 %', () => {
  assert.equal(tapZone(99, W), 'prev'); assert.equal(tapZone(100, W), 'menu')
  assert.equal(tapZone(300, W), 'menu'); assert.equal(tapZone(301, W), 'next')
})
console.log(`\n${n} tests passed`)
