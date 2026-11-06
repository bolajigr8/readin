// Run:  node --experimental-strip-types tests/client-ip.test.mjs   (Node 22+)
import assert from 'node:assert/strict'
import { resolveClientIp } from '../src/utils/clientIp.ts'

let n = 0
const t = (name, fn) => { fn(); n++; console.log('ok -', name) }
const req = (headers, ip = '10.0.0.7') => ({ headers, ip })

t('production: CF-Connecting-IP wins over the proxy address', () => {
  assert.deepEqual(resolveClientIp(req({ 'cf-connecting-ip': '102.89.1.2' }), true), { ip: '102.89.1.2', source: 'cf-connecting-ip' })
})
t('production: True-Client-IP when Cloudflare header is missing', () => {
  assert.deepEqual(resolveClientIp(req({ 'true-client-ip': '2c0f:f5c0::1' }), true), { ip: '2c0f:f5c0::1', source: 'true-client-ip' })
})
t('production: garbage header ignored → req.ip', () => {
  assert.deepEqual(resolveClientIp(req({ 'cf-connecting-ip': '1.2.3.4, 5.6.7.8' }), true), { ip: '10.0.0.7', source: 'req.ip' })
})
t('production: no headers → req.ip', () => {
  assert.equal(resolveClientIp(req({}), true).source, 'req.ip')
})
t('not production: headers are ignored (could be faked)', () => {
  assert.deepEqual(resolveClientIp(req({ 'cf-connecting-ip': '102.89.1.2' }), false), { ip: '10.0.0.7', source: 'req.ip' })
})
t('missing req.ip → empty string, never undefined', () => {
  assert.equal(resolveClientIp({ headers: {}, ip: undefined }, false).ip, '')
})
console.log(`\n${n} tests passed`)
