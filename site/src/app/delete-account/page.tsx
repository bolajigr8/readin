import type { Metadata } from 'next'
import { LegalPage } from '@/components/legal-page'
import { SUPPORT_EMAIL } from '@/components/site-footer'

export const metadata: Metadata = {
  title: 'Delete your account',
  description: 'How to delete your ReadIn account and data, in the app or on the web.',
  alternates: { canonical: '/delete-account' },
}

/** The web deletion flow itself runs on the API server (e-mailed 1-hour link → confirm page). */
const WEB_DELETE_URL = 'https://readin-ehzw.onrender.com/delete-account'

export default function DeleteAccountPage() {
  return (
    <LegalPage title="Delete your ReadIn account" updated={`ReadIn app · developer: ReadIn (${SUPPORT_EMAIL})`}>
      <h2>Option 1 — in the app</h2>
      <ol>
        <li>Open <strong>ReadIn</strong> and go to <strong>Profile</strong>.</li>
        <li>Scroll to <strong>Account</strong> and tap <strong>Delete account</strong>.</li>
        <li>Enter your password, type <strong>DELETE</strong> and confirm.</li>
      </ol>

      <h2>Option 2 — without the app</h2>
      <p>
        Enter your e-mail on our deletion page. We send you a confirmation link (valid for 1 hour); the account is deleted
        only after you press the final button.
      </p>
      <p className="!my-6">
        <a
          href={WEB_DELETE_URL}
          rel="noopener"
          className="inline-block rounded-2xl bg-brand px-6 py-3.5 font-semibold !text-white !no-underline transition hover:opacity-90"
        >
          Open the deletion page
        </a>
      </p>
      <p>
        Can’t receive e-mail any more? Write to <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a> from the address
        of your account, or explain your situation, and we will help.
      </p>

      <h2>What is deleted</h2>
      <ul>
        <li>Your account: e-mail address, name and password.</li>
        <li>Your library list and any book files stored in our cloud.</li>
        <li>Notes, highlights, bookmarks, reading progress, shelves and reading habits.</li>
        <li>Free trials and settings linked to your account.</li>
        <li>When you delete in the app, ReadIn’s data on that phone (imported books, settings) is removed too.</li>
      </ul>

      <h2>What is kept, and for how long</h2>
      <ul>
        <li>
          <strong>Payment records</strong> (amount, date, plan, payment reference) are kept <strong>without your e-mail
          address</strong> for as long as accounting and tax law requires (usually up to 6 years).
        </li>
        <li>Server logs that may contain your IP address disappear within a few weeks.</li>
      </ul>
      <p className="rounded-2xl border border-line bg-bg-2 p-5">
        Subscribed through <strong>Google Play</strong>? Deleting your account does not cancel Google’s billing. Cancel
        first in the Play Store: <strong>Profile → Payments &amp; subscriptions → Subscriptions → ReadIn → Cancel</strong>.
      </p>
    </LegalPage>
  )
}
