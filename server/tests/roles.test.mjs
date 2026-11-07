// Run:  node --experimental-strip-types tests/roles.test.mjs   (Node 22+)
// S5 — roles & permissions (pure).
import assert from 'node:assert/strict'
import {
  PERMISSIONS, PRESETS, cleanPermissions, effectivePermissions, effectiveRole, isStaff, ownerEmails, parseRole,
  planForRole, teamChangeProblem,
} from '../src/services/roles.logic.ts'

let n = 0
const t = (name, fn) => { fn(); n++; console.log('ok -', name) }
const owners = ownerEmails(' Boss@ReadIn.test , ,other@x.test')

t('ADMIN_EMAILS parsed: trimmed, lower case, empties dropped', () => assert.deepEqual(owners, ['boss@readin.test', 'other@x.test']))
t('listed + verified e-mail = owner, whatever the database says (break-glass)', () => {
  assert.equal(effectiveRole({ role: 'user', email: 'BOSS@readin.test', isEmailVerified: true }, owners), 'owner')
  assert.equal(effectiveRole({ role: 'admin', email: 'boss@readin.test', isEmailVerified: true }, owners), 'owner')
})
t('listed but e-mail NOT confirmed → no owner power', () => {
  assert.equal(effectiveRole({ role: 'user', email: 'boss@readin.test', isEmailVerified: false }, owners), 'user')
})
t('unknown stored role → user', () => {
  assert.equal(parseRole('superuser'), 'user'); assert.equal(parseRole(undefined), 'user'); assert.equal(parseRole('tester'), 'tester')
})
t('owner has every permission incl. team.manage', () => assert.deepEqual(effectivePermissions('owner', []), [...PERMISSIONS]))
t('admin has only what was given, never team.manage', () => {
  assert.deepEqual(effectivePermissions('admin', ['users.read', 'team.manage', 'nonsense']), ['users.read'])
  assert.deepEqual(effectivePermissions('admin', null), [])
})
t('tester and user have no admin permissions', () => {
  assert.deepEqual(effectivePermissions('tester', ['users.read']), [])
  assert.deepEqual(effectivePermissions('user', ['users.read']), [])
})
t('cleanPermissions drops unknown and team.manage', () => {
  assert.deepEqual(cleanPermissions(['billing.read', 'team.manage', 'x', 'billing.read']), ['billing.read'])
})
t('presets never contain team.manage; full = everything else', () => {
  for (const p of Object.values(PRESETS)) assert.ok(!p.permissions.includes('team.manage'))
  assert.equal(PRESETS.full.permissions.length, PERMISSIONS.length - 1)
})
t('staff = owner/admin only', () => assert.deepEqual(['user', 'tester', 'admin', 'owner'].map(isStaff), [false, false, true, true]))
t('testers and the team use the app like Premium; users keep their plan', () => {
  assert.equal(planForRole('tester', 'free'), 'premium'); assert.equal(planForRole('owner', 'free'), 'premium')
  assert.equal(planForRole('user', 'free'), 'free'); assert.equal(planForRole('user', 'premium'), 'premium')
})
t('team rules: not yourself; never the last owner', () => {
  const base = { actorId: 'a', targetId: 'b', targetIsOwnerNow: true, targetWillBeOwner: false, ownersNow: 1 }
  assert.match(teamChangeProblem({ ...base, targetId: 'a' }), /your own/)
  assert.match(teamChangeProblem(base), /last owner/)
  assert.equal(teamChangeProblem({ ...base, ownersNow: 2 }), null)
  assert.equal(teamChangeProblem({ ...base, targetIsOwnerNow: false }), null)
})
console.log(`\n${n} tests passed`)
