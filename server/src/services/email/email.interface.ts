import type { PremiumReminderInput } from './templates.js'

/**
 * IEmailProvider — contract that every email provider must satisfy.
 *
 * To add a new provider (SendGrid, Mailgun, Postmark, etc.):
 *   1. Create a new file in providers/ that implements this interface.
 *   2. In email.service.ts, swap `new ResendProvider()` for your new class.
 *   That's it — zero other changes needed.
 */
export interface IEmailProvider {
  sendVerificationEmail(to: string, name: string, token: string): Promise<void>
  sendPasswordResetEmail(to: string, name: string, token: string): Promise<void>
  sendWelcomeEmail(to: string, name: string): Promise<void>
  sendPasswordChangedEmail(to: string, name: string): Promise<void>
  /** Web account deletion: the 1-hour confirmation link. */
  sendAccountDeletionLinkEmail(to: string, name: string, token: string): Promise<void>
  /** Sent right before the account is deleted (we still know the address). */
  sendAccountDeletedEmail(to: string, name: string): Promise<void>
  sendPaymentReceiptEmail(input: {
    to: string
    name: string
    planName: string
    amountKobo: number
    reference: string
    paidAt: Date
    premiumUntil: Date
  }): Promise<void>
  /** Premium ending / ended reminder (S9.2). */
  sendPremiumReminderEmail(input: { to: string } & PremiumReminderInput): Promise<void>
}
