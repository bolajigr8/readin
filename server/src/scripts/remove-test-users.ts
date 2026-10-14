/**
 * Removes the demo accounts created by `seed` (alice/bob/carol/dave @readin.test)
 * and everything they own. The seed password is public in the repository, so
 * these accounts must NOT exist on the live database.
 *
 *   npx tsx src/scripts/remove-test-users.ts            → shows what would be deleted
 *   npx tsx src/scripts/remove-test-users.ts --confirm  → deletes
 */
import 'dotenv/config'
import mongoose from 'mongoose'
import { connectDB } from '../config/db.js'
import { User } from '../models/user.model.js'
import { Book } from '../models/book.model.js'
import { Annotation } from '../models/annotation.model.js'
import { Bookmark } from '../models/bookmark.model.js'
import { Progress } from '../models/progress.model.js'
import { UserFeature } from '../models/userFeature.model.js'
import { UserData } from '../models/userData.model.js'

const main = async (): Promise<void> => {
  await connectDB()
  const confirm = process.argv.includes('--confirm')

  const users = await User.find({ email: /@readin\.test$/i }).select('email').lean()
  const ids = users.map((u) => u._id)

  console.log(`\nDemo accounts found: ${users.length}`)
  for (const u of users) console.log('  -', u.email)

  if (users.length === 0) {
    console.log('Nothing to remove.\n')
  } else if (!confirm) {
    console.log('\nDry run — nothing was deleted. Add --confirm to delete them and all their data.\n')
  } else {
    const r = await Promise.all([
      Book.deleteMany({ userId: { $in: ids } }),
      Annotation.deleteMany({ userId: { $in: ids } }),
      Bookmark.deleteMany({ userId: { $in: ids } }),
      Progress.deleteMany({ userId: { $in: ids } }),
      UserFeature.deleteMany({ userId: { $in: ids } }),
      UserData.deleteMany({ userId: { $in: ids } }),
    ])
    await User.deleteMany({ _id: { $in: ids } })
    console.log(`\n✓ Deleted ${users.length} accounts, ${r[0].deletedCount} books, ${r[1].deletedCount} annotations.\n`)
  }
  await mongoose.disconnect()
}

main().catch((err: unknown) => {
  console.error('\n✗ Failed:', err instanceof Error ? err.message : err, '\n')
  process.exit(1)
})
