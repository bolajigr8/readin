/**
 * S5 role migration — run ONCE on production after taking a MongoDB Atlas backup/snapshot.
 *
 *   npx tsx src/scripts/migrate-roles.ts            # dry run: shows what would change, changes nothing
 *   npx tsx src/scripts/migrate-roles.ts --confirm  # does it
 *
 * Old accounts with role "admin":
 *   - e-mail in ADMIN_EMAILS → "owner"
 *   - any other "admin"      → "admin" with every permission except team.manage (same power as before S5)
 * Idempotent: running it again changes nothing. (Not required to keep access: an ADMIN_EMAILS account with a
 * confirmed e-mail is always an owner anyway.)
 */
import 'dotenv/config'
import mongoose from 'mongoose'
import { connectDB } from '../config/db.js'
import { User } from '../models/user.model.js'
import { PRESETS, ownerEmails } from '../services/roles.logic.js'

const confirm = process.argv.includes('--confirm')

const main = async (): Promise<void> => {
  await connectDB()
  const owners = ownerEmails(process.env['ADMIN_EMAILS'])
  const legacy = await User.find({ role: 'admin', permissions: { $size: 0 } }).select('email role permissions')
  if (legacy.length === 0) console.log('Nothing to migrate (no old-style admins).')
  for (const u of legacy) {
    const toOwner = owners.includes(u.email.toLowerCase())
    console.log(`${confirm ? 'MIGRATE' : 'would migrate'}: admin → ${toOwner ? 'owner' : 'admin (full, without team)'}  (id ${String(u._id)})`)
    if (!confirm) continue
    u.role = toOwner ? 'owner' : 'admin'
    u.permissions = toOwner ? [] : [...PRESETS.full.permissions]
    u.roleChangedAt = new Date()
    await u.save()
  }
  if (!confirm && legacy.length) console.log('\nDry run only. Add --confirm to apply.')
  await mongoose.disconnect()
}

main().catch(async (err: unknown) => {
  console.error('Failed:', err instanceof Error ? err.message : err)
  await mongoose.disconnect().catch(() => undefined)
  process.exit(1)
})
