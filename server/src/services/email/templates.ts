/**
 * Professional, email-client-safe HTML (table layout, inline CSS, no images that
 * can be blocked). Every template returns { subject, html, text }.
 */

const BRAND = 'ReadIn'
const ORANGE = '#F97316'
const INK = '#18181b'
const MUTED = '#52525b'
const SOFT = '#71717a'

export const esc = (s: string): string =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')

export interface Rendered {
  subject: string
  html: string
  text: string
}

interface Layout {
  preheader: string
  title: string
  /** Pre-built HTML for the body (already escaped). */
  body: string
  button?: { label: string; url: string }
  /** Small grey print under the button. */
  after?: string
  /** Shown above the footer as a safety note. */
  notice?: string
}

const button = (label: string, url: string): string => `
<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:28px 0 8px 0;">
  <tr><td align="center" bgcolor="${ORANGE}" style="border-radius:10px;">
    <a href="${esc(url)}" target="_blank" style="display:inline-block;padding:15px 34px;font-family:Arial,Helvetica,sans-serif;font-size:16px;font-weight:700;line-height:1;color:#ffffff;text-decoration:none;border-radius:10px;background:${ORANGE};">${esc(label)}</a>
  </td></tr>
</table>`

export const layout = (l: Layout): string => `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<title>${esc(l.title)}</title>
</head>
<body style="margin:0;padding:0;background:#f4f4f5;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:#f4f4f5;font-size:1px;line-height:1px;">${esc(l.preheader)}&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#f4f4f5">
  <tr><td align="center" style="padding:32px 12px;">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:600px;">
      <tr><td align="center" style="padding:0 0 18px 0;">
        <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
          <td bgcolor="${ORANGE}" width="44" height="44" align="center" style="width:44px;height:44px;border-radius:11px;font-size:24px;line-height:44px;">&#128214;</td>
          <td style="padding-left:12px;font-family:Arial,Helvetica,sans-serif;font-size:24px;font-weight:800;letter-spacing:-0.5px;color:${INK};">${BRAND}</td>
        </tr></table>
      </td></tr>
      <tr><td bgcolor="#ffffff" style="background:#ffffff;border-radius:16px;border-top:5px solid ${ORANGE};padding:38px 36px 30px 36px;font-family:Arial,Helvetica,sans-serif;color:${INK};">
        <h1 style="margin:0 0 16px 0;font-size:25px;line-height:1.3;font-weight:800;color:${INK};">${esc(l.title)}</h1>
        <div style="font-size:16px;line-height:1.65;color:${MUTED};">${l.body}</div>
        ${l.button ? button(l.button.label, l.button.url) : ''}
        ${
          l.button
            ? `<p style="margin:18px 0 0 0;font-size:13px;line-height:1.6;color:${SOFT};">Button not working? Copy this link into your browser:<br><a href="${esc(l.button.url)}" style="color:${ORANGE};word-break:break-all;">${esc(l.button.url)}</a></p>`
            : ''
        }
        ${l.after ? `<p style="margin:16px 0 0 0;font-size:13px;line-height:1.6;color:${SOFT};">${l.after}</p>` : ''}
        ${
          l.notice
            ? `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:26px;"><tr><td bgcolor="#fff7ed" style="background:#fff7ed;border:1px solid #fed7aa;border-radius:10px;padding:14px 16px;font-size:13px;line-height:1.6;color:#9a3412;">${l.notice}</td></tr></table>`
            : ''
        }
      </td></tr>
      <tr><td align="center" style="padding:22px 16px 0 16px;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.7;color:${SOFT};">
        <strong style="color:${MUTED};">${BRAND}</strong> &middot; Your personal reading platform<br>
        You received this e-mail because of an action on your ${BRAND} account.<br>
        If this wasn&rsquo;t you, you can safely ignore it.
      </td></tr>
    </table>
  </td></tr>
</table>
</body>
</html>`

const first = (name: string): string => esc((name || 'there').split(' ')[0] ?? 'there')

export const verificationEmail = (name: string, url: string): Rendered => ({
  subject: `Confirm your e-mail to start reading, ${(name || 'there').split(' ')[0]}`,
  html: layout({
    preheader: 'One tap to confirm your ReadIn account.',
    title: `Welcome to ReadIn, ${first(name)}!`,
    body: `<p style="margin:0 0 12px 0;">Thanks for joining. Confirm your e-mail address to activate your account and start building your library.</p>`,
    button: { label: 'Confirm my e-mail', url },
    after: 'This link works for <strong>24 hours</strong>.',
    notice: '<strong>Didn&rsquo;t create a ReadIn account?</strong> Just ignore this message &mdash; nothing will happen.',
  }),
  text: `Welcome to ReadIn, ${name || 'there'}!\n\nConfirm your e-mail to activate your account:\n${url}\n\nThis link works for 24 hours. If you did not create a ReadIn account, ignore this e-mail.`,
})

export const passwordResetEmail = (name: string, url: string): Rendered => ({
  subject: 'Reset your ReadIn password',
  html: layout({
    preheader: 'Choose a new password for your ReadIn account.',
    title: 'Reset your password',
    body: `<p style="margin:0 0 12px 0;">Hi ${first(name)}, we received a request to reset the password of your ReadIn account. Tap the button to choose a new one.</p>`,
    button: { label: 'Choose a new password', url },
    after: 'This link works for <strong>1 hour</strong> and can be used once.',
    notice: '<strong>Didn&rsquo;t ask for this?</strong> Your password has <strong>not</strong> been changed &mdash; you can ignore this e-mail. If you keep receiving it, please contact support.',
  }),
  text: `Hi ${name || 'there'},\n\nReset your ReadIn password:\n${url}\n\nThis link works for 1 hour. If you did not ask for this, ignore this e-mail - your password has not changed.`,
})

export const welcomeEmail = (name: string): Rendered => {
  const li = (t: string): string =>
    `<tr><td valign="top" style="padding:7px 12px 7px 0;color:${ORANGE};font-size:16px;">&#10003;</td><td style="padding:7px 0;font-size:15px;line-height:1.55;color:${MUTED};">${t}</td></tr>`
  return {
    subject: `You're in, ${(name || 'there').split(' ')[0]} — happy reading!`,
    html: layout({
      preheader: 'Your e-mail is confirmed. Here is what you can do.',
      title: `You're all set, ${first(name)}!`,
      body: `<p style="margin:0 0 14px 0;">Your e-mail is confirmed and your account is ready. Here is what you can do in ReadIn:</p>
<table role="presentation" cellpadding="0" cellspacing="0" border="0">
${li('Read <strong>EPUB, PDF, Word, Excel</strong> and more &mdash; even offline')}
${li('Highlight, bookmark and keep <strong>notes</strong> that sync')}
${li('Discover thousands of <strong>free classic books</strong>')}
${li('Build a daily <strong>reading habit</strong> with reminders')}
</table>
<p style="margin:16px 0 0 0;">Open the app and sign in with your e-mail and password.</p>`,
    }),
    text: `You're all set, ${name || 'there'}! Your e-mail is confirmed. Open the ReadIn app and sign in to start reading.`,
  }
}

export const passwordChangedEmail = (name: string): Rendered => ({
  subject: 'Your ReadIn password was changed',
  html: layout({
    preheader: 'Your password was just changed.',
    title: 'Your password was changed',
    body: `<p style="margin:0 0 12px 0;">Hi ${first(name)}, the password of your ReadIn account was just changed and you were signed out of all devices.</p>`,
    notice: '<strong>Wasn&rsquo;t you?</strong> Reset your password again from the sign-in screen (&ldquo;Forgot password&rdquo;) right away, and contact support.',
  }),
  text: `Hi ${name || 'there'}, your ReadIn password was just changed and you were signed out of all devices. If this wasn't you, reset your password again right away.`,
})

export interface ReceiptInput {
  name: string
  planName: string
  amountText: string
  reference: string
  paidAt: Date
  premiumUntil: Date
}

const dateText = (d: Date): string =>
  d.toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Africa/Lagos' })

export const receiptEmail = (r: ReceiptInput): Rendered => {
  const row = (k: string, v: string): string =>
    `<tr><td style="padding:10px 0;border-bottom:1px solid #f4f4f5;font-size:14px;color:${SOFT};">${k}</td><td align="right" style="padding:10px 0;border-bottom:1px solid #f4f4f5;font-size:14px;font-weight:700;color:${INK};">${v}</td></tr>`
  return {
    subject: `Payment received — ReadIn Premium is active`,
    html: layout({
      preheader: `${r.amountText} received. Premium is active until ${dateText(r.premiumUntil)}.`,
      title: 'Thank you — Premium is active!',
      body: `<p style="margin:0 0 16px 0;">Hi ${first(r.name)}, we received your payment. Here is your receipt:</p>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
${row('Plan', esc(r.planName))}
${row('Amount paid', esc(r.amountText))}
${row('Date', esc(dateText(r.paidAt)))}
${row('Premium active until', esc(dateText(r.premiumUntil)))}
${row('Reference', `<span style="font-family:Consolas,Menlo,monospace;font-size:12px;">${esc(r.reference)}</span>`)}
</table>
<p style="margin:18px 0 0 0;">Your new features are already unlocked in the app. Enjoy your reading!</p>`,
      after: 'Payments are processed securely by Paystack. We never see or store your card details.',
    }),
    text: `Thank you! Payment received.\n\nPlan: ${r.planName}\nAmount: ${r.amountText}\nDate: ${dateText(r.paidAt)}\nPremium active until: ${dateText(r.premiumUntil)}\nReference: ${r.reference}\n\nPayments are processed securely by Paystack.`,
  }
}
