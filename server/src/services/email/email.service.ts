import { ResendProvider } from '../providers/resend.provider.js'
import type { IEmailProvider } from './email.interface.js'

/**
 * EmailService — thin wrapper around whichever IEmailProvider is active.
 * To swap providers, change only the constructor call at the bottom of this file.
 */
export class EmailService {
  private readonly provider: IEmailProvider

  constructor(provider: IEmailProvider) {
    this.provider = provider
  }

  sendVerificationEmail(
    to: string,
    name: string,
    token: string,
  ): Promise<void> {
    return this.provider.sendVerificationEmail(to, name, token)
  }

  sendPasswordResetEmail(
    to: string,
    name: string,
    token: string,
  ): Promise<void> {
    return this.provider.sendPasswordResetEmail(to, name, token)
  }

  sendWelcomeEmail(to: string, name: string): Promise<void> {
    return this.provider.sendWelcomeEmail(to, name)
  }
}

// ── Singleton — swap `new ResendProvider()` here to change the active provider
export const emailService = new EmailService(new ResendProvider())
