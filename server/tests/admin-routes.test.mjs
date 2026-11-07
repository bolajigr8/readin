// Run:  node tests/admin-routes.test.mjs
// S5 — every admin route must name its permission: can('…') or anyTeamMember. A new route without one fails here.
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const src = readFileSync(new URL('../src/routes/admin.routes.ts', import.meta.url), 'utf8')
const logic = readFileSync(new URL('../src/services/roles.logic.ts', import.meta.url), 'utf8')
const known = new Set([...logic.slice(logic.indexOf('PERMISSIONS = ['), logic.indexOf('] as const')).matchAll(/'([a-z]+\.[a-z]+)'/g)].map((m) => m[1]))
const routes = [...src.matchAll(/^router\.(get|post|put|patch|delete)\((.*)\)\s*$/gm)]
assert.ok(routes.length >= 25, `expected the admin routes, found ${routes.length}`)
assert.match(src, /router\.use\(protect, requireStaff\)/, 'requireStaff must guard every admin route')
for (const [line, , args] of routes) {
  const perm = args.match(/can\('([^']+)'\)/)?.[1]
  assert.ok(perm || /anyTeamMember/.test(args), `route without a permission: ${line}`)
  if (perm) assert.ok(known.has(perm), `unknown permission ${perm} in: ${line}`)
}
for (const m of ['/team', '/team/:id']) {
  for (const [line] of routes.filter(([l]) => l.includes(`'${m}'`))) assert.match(line, /can\('team\.manage'\)/, line)
}
console.log(`ok - ${routes.length} admin routes, each with a permission (team routes = team.manage)\n\n1 tests passed`)
