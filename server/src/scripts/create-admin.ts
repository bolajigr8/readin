/**
 * Creates (or upgrades) THE administrator account.
 *
 *   ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='a-long-secret' npx tsx src/scripts/create-admin.ts
 *   (on the server after `pnpm build`:  node dist/scripts/create-admin.js)
 *
 * • The password is read from the environment and is NEVER printed or stored
 *   anywhere except as a bcrypt hash in the database.
 * • Running it again with a new password resets the admin password and signs the
 *   admin out of every session.
 * • This script is the ONLY way to make an administrator: the API cannot.
 */
import 'dotenv/config'
import bcrypt from 'bcryptjs'
import mongoose from 'mongoose'
import { connectDB } from '../config/db.js'
import { User } from '../models/user.model.js'

const email = (process.env['ADMIN_EMAIL'] ?? '').trim().toLowerCase()
const password = process.env['ADMIN_PASSWORD'] ?? ''
const name = (process.env['ADMIN_NAME'] ?? 'Administrator').trim() || 'Administrator'

const fail = (msg: string): never => {
  console.error(`\n✗ ${msg}\n`)
  process.exit(1)
}

if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) fail('Set ADMIN_EMAIL to a valid e-mail address.')

const classes = [/[a-z]/, /[A-Z]/, /\d/, /[^A-Za-z0-9]/].filter((r) => r.test(password)).length
if (password.length < 14 || classes < 3) {
  fail(
    'ADMIN_PASSWORD must be at least 14 characters and mix at least 3 of: lower case, upper case, digits, symbols.\n' +
      "  Tip: openssl rand -base64 24",
  )
}

const main = async (): Promise<void> => {
  await connectDB()

  const passwordHash = await bcrypt.hash(password, 12)
  const existing = await User.findOne({ email })

  if (existing) {
    existing.role = 'admin'
    existing.passwordHash = passwordHash
    existing.isEmailVerified = true
    existing.disabled = false
    existing.plan = 'premium'
    existing.refreshTokens = []
    await existing.save()
    console.log(`\n✓ Existing account promoted to administrator: ${email}`)
  } else {
    await User.create({
      email,
      passwordHash,
      displayName: name,
      role: 'admin',
      plan: 'premium',
      isEmailVerified: true,
    })
    console.log(`\n✓ Administrator created: ${email}`)
  }

  console.log('  Sign in with this e-mail and the password you set. The password is not stored anywhere else.\n')
  await mongoose.disconnect()
}

main().catch((err: unknown) => {
  console.error('\n✗ Failed:', err instanceof Error ? err.message : err, '\n')
  process.exit(1)
})
