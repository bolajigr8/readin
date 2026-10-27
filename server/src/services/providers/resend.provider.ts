// To swap email provider: implement IEmailProvider and update email.service.ts

import { Resend } from 'resend'
import type { IEmailProvider } from '../email/email.interface.js'
import {
  passwordChangedEmail,
  passwordResetEmail,
  receiptEmail,
  verificationEmail,
  welcomeEmail,
  type Rendered,
} from '../email/templates.js'
import { formatNaira } from '../billing.logic.js'

export class ResendProvider implements IEmailProvider {
  private readonly client: Resend
  private readonly from: string
  private readonly appUrl: string

  constructor() {
    const apiKey = process.env['RESEND_API_KEY']
    if (!apiKey) throw new Error('RESEND_API_KEY is not configured')

    const from = process.env['EMAIL_FROM']
    if (!from) throw new Error('EMAIL_FROM is not configured')

    this.client = new Resend(apiKey)
    this.from = from
    this.appUrl = (process.env['APP_URL'] ?? 'http://localhost:5000').trim().replace(/\/+$/, '')
  }

  private async send(to: string, mail: Rendered): Promise<void> {
    const { error } = await this.client.emails.send({
      from: this.from,
      to,
      subject: mail.subject,
      html: mail.html,
      text: mail.text,
    })
    // Resend reports problems (unverified domain, bad key…) in `error`, it does not throw.
    if (error) throw new Error(`Resend: ${error.message}`)
  }

  /** Pages (not API JSON) — see routes/pages.routes.ts */
  sendVerificationEmail(to: string, name: string, token: string): Promise<void> {
    return this.send(to, verificationEmail(name, `${this.appUrl}/verify-email?token=${encodeURIComponent(token)}`))
  }

  sendPasswordResetEmail(to: string, name: string, token: string): Promise<void> {
    return this.send(to, passwordResetEmail(name, `${this.appUrl}/reset-password?token=${encodeURIComponent(token)}`))
  }

  sendWelcomeEmail(to: string, name: string): Promise<void> {
    return this.send(to, welcomeEmail(name))
  }

  sendPasswordChangedEmail(to: string, name: string): Promise<void> {
    return this.send(to, passwordChangedEmail(name))
  }

  sendPaymentReceiptEmail(input: Parameters<IEmailProvider['sendPaymentReceiptEmail']>[0]): Promise<void> {
    return this.send(
      input.to,
      receiptEmail({
        name: input.name,
        planName: input.planName,
        amountText: formatNaira(input.amountKobo),
        reference: input.reference,
        paidAt: input.paidAt,
        premiumUntil: input.premiumUntil,
      }),
    )
  }
}
