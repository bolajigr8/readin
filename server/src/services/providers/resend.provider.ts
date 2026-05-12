// To swap email provider: implement IEmailProvider and update email.service.ts

import { Resend } from 'resend'
import { IEmailProvider } from '../email/email.interface'

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
    this.appUrl = process.env['APP_URL'] ?? 'http://localhost:5000'
  }

  async sendVerificationEmail(
    to: string,
    name: string,
    token: string,
  ): Promise<void> {
    const verifyUrl = `${this.appUrl}/api/v1/auth/verify-email/${token}`

    await this.client.emails.send({
      from: this.from,
      to,
      subject: 'Verify your ReadIn email address',
      html: `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 560px; margin: 0 auto; color: #1a1a2e;">
          <h1 style="font-size: 24px; margin-bottom: 8px;">Welcome to ReadIn, ${name}! 👋</h1>
          <p style="color: #555; line-height: 1.6;">Thanks for signing up. Please verify your email address to activate your account.</p>
          
            href="${verifyUrl}"
            style="display: inline-block; margin: 24px 0; padding: 14px 28px; background: #6c63ff; color: #fff; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 15px;"
          >
            Verify Email Address
          </a>
          <p style="color: #888; font-size: 13px;">This link expires in <strong>24 hours</strong>. If you didn't create a ReadIn account, you can safely ignore this email.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 32px 0;" />
          <p style="color: #aaa; font-size: 12px;">ReadIn · Your personal reading platform</p>
        </div>
      `,
    })
  }

  async sendPasswordResetEmail(
    to: string,
    name: string,
    token: string,
  ): Promise<void> {
    const resetUrl = `${this.appUrl}/reset-password?token=${token}`

    await this.client.emails.send({
      from: this.from,
      to,
      subject: 'Reset your ReadIn password',
      html: `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 560px; margin: 0 auto; color: #1a1a2e;">
          <h1 style="font-size: 24px; margin-bottom: 8px;">Password Reset Request</h1>
          <p style="color: #555; line-height: 1.6;">Hi ${name}, we received a request to reset your ReadIn password.</p>
          
            href="${resetUrl}"
            style="display: inline-block; margin: 24px 0; padding: 14px 28px; background: #6c63ff; color: #fff; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 15px;"
          >
            Reset Password
          </a>
          <p style="color: #888; font-size: 13px;">This link expires in <strong>1 hour</strong>. If you didn't request a password reset, ignore this email — your password won't change.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 32px 0;" />
          <p style="color: #aaa; font-size: 12px;">ReadIn · Your personal reading platform</p>
        </div>
      `,
    })
  }

  async sendWelcomeEmail(to: string, name: string): Promise<void> {
    await this.client.emails.send({
      from: this.from,
      to,
      subject: "You're verified — welcome to ReadIn! 📚",
      html: `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 560px; margin: 0 auto; color: #1a1a2e;">
          <h1 style="font-size: 24px; margin-bottom: 8px;">You're all set, ${name}! 🎉</h1>
          <p style="color: #555; line-height: 1.6;">Your email has been verified and your ReadIn account is ready.</p>
          <p style="color: #555; line-height: 1.6;">Here's what you can do:</p>
          <ul style="color: #555; line-height: 2;">
            <li>Upload PDFs and convert them to EPUB for a better reading experience</li>
            <li>Read with highlights, bookmarks, and personal notes</li>
            <li>Discover thousands of free public domain books</li>
            <li>Listen with built-in text-to-speech audio</li>
          </ul>
          <p style="color: #555;">Happy reading!</p>
          <p style="color: #888; font-size: 13px;">— The ReadIn Team</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 32px 0;" />
          <p style="color: #aaa; font-size: 12px;">ReadIn · Your personal reading platform</p>
        </div>
      `,
    })
  }
}
