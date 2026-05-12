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
}
