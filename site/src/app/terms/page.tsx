import type { Metadata } from 'next'
import Link from 'next/link'
import { LegalPage } from '@/components/legal-page'
import { SUPPORT_EMAIL } from '@/components/site-footer'

export const metadata: Metadata = {
  title: 'Terms of use',
  description: 'The rules for using the ReadIn reading app and ReadIn Premium.',
  alternates: { canonical: '/terms' },
}

export default function TermsPage() {
  return (
    <LegalPage title="Terms of use" updated="Last updated: 6 November 2026">
      <p>By creating an account or using ReadIn you agree to these terms. Please read them — they are short.</p>

      <h2>1. Your account</h2>
      <ul>
        <li>Give a real e-mail address and keep your password to yourself. You are responsible for what happens in your account.</li>
        <li>You must be at least 13 years old.</li>
        <li>You can delete your account at any time (<Link prefetch={false} href="/delete-account">how</Link>).</li>
      </ul>

      <h2>2. Your books and content</h2>
      <ul>
        <li>Your files stay yours. Only import books and documents you have the right to read and keep.</li>
        <li>Free classics come from Project Gutenberg and are in the public domain in the USA. Copyright rules differ between countries — check the rules where you live before sharing them.</li>
        <li>Do not use ReadIn to share pirated content, malware or anything illegal.</li>
      </ul>

      <h2>3. ReadIn Premium</h2>
      <ul>
        <li><strong>Play Store version:</strong> Premium is a subscription billed by Google Play (monthly or yearly). It renews automatically until you cancel in the Play Store (Profile → Payments &amp; subscriptions). Refunds follow Google Play’s refund policy.</li>
        <li><strong>Website/APK version:</strong> Premium is paid with Paystack for a fixed period (for example 30 days) and does <strong>not</strong> renew by itself. Buying again adds time after the time you have left.</li>
        <li>Premium belongs to your account and works on every phone where you sign in, whichever way you paid.</li>
        <li>Prices are shown before you pay. If we change prices, the new price applies to the next period only.</li>
        <li>If a payment fails or is refunded or reversed, Premium may stop.</li>
      </ul>

      <h2>4. Fair use</h2>
      <p>Do not try to break, overload, copy or misuse the service or other people’s accounts. We may suspend accounts that do, after warning you where possible.</p>

      <h2>5. Changes and availability</h2>
      <p>We keep improving ReadIn, so features may change. We try hard to keep the service running, but it may sometimes be unavailable (for example during maintenance). Books stored on your phone keep working offline.</p>

      <h2>6. No warranty, limited liability</h2>
      <p>ReadIn is provided “as is”. To the extent the law allows, we are not liable for indirect losses or for lost data — keep your own copies of important files. Nothing here limits rights you have under consumer law.</p>

      <h2>7. Law</h2>
      <p>These terms are governed by the laws of the Federal Republic of Nigeria.</p>

      <h2>8. Contact</h2>
      <p><a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a></p>
    </LegalPage>
  )
}
