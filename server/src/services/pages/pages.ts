/**
 * Server-rendered pages people open from e-mails / after paying (instead of raw
 * JSON). One shared, responsive, dark-mode-aware shell. No external assets.
 */

const esc = (s: string): string =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')

export type Tone = 'success' | 'error' | 'info' | 'warning'

const ICONS: Record<Tone, string> = {
  success:
    '<svg viewBox="0 0 24 24" width="38" height="38" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.2 4.2L19 7"/></svg>',
  error:
    '<svg viewBox="0 0 24 24" width="38" height="38" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>',
  info: '<svg viewBox="0 0 24 24" width="38" height="38" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M12 8h.01M11 12h1v5h1"/><circle cx="12" cy="12" r="9"/></svg>',
  warning:
    '<svg viewBox="0 0 24 24" width="38" height="38" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 8v5M12 17h.01"/><path d="M10.3 3.9L2.4 18a2 2 0 001.7 3h15.8a2 2 0 001.7-3L13.7 3.9a2 2 0 00-3.4 0z"/></svg>',
}

export interface PageOptions {
  title: string
  tone: Tone
  heading: string
  /** Escaped-by-caller HTML for the message area. */
  message: string
  /** Extra HTML under the message (forms, receipt tables…). */
  extra?: string
  /** Optional inline script (must be self-contained). */
  script?: string
  status?: number
}

export const renderPage = (o: PageOptions): string => `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<meta name="color-scheme" content="light dark">
<title>${esc(o.title)} · ReadIn</title>
<style>
:root{--bg1:#fff7ed;--bg2:#ffedd5;--card:#ffffff;--ink:#18181b;--muted:#52525b;--soft:#71717a;--line:#e4e4e7;--brand:#f97316;--brand-d:#ea580c;
--ok:#16a34a;--ok-bg:#dcfce7;--err:#dc2626;--err-bg:#fee2e2;--info:#0284c7;--info-bg:#e0f2fe;--warn:#d97706;--warn-bg:#fef3c7;--field:#fafafa}
@media (prefers-color-scheme:dark){:root{--bg1:#18181b;--bg2:#0b0b0d;--card:#232326;--ink:#fafafa;--muted:#c4c4cc;--soft:#a1a1aa;--line:#3f3f46;--ok-bg:#14532d;--err-bg:#7f1d1d;--info-bg:#0c4a6e;--warn-bg:#78350f;--field:#1c1c1f}}
*{box-sizing:border-box}
html,body{margin:0;min-height:100%}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;background:linear-gradient(160deg,var(--bg1),var(--bg2));color:var(--ink);min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:28px 16px;-webkit-font-smoothing:antialiased}
.brand{display:flex;align-items:center;gap:11px;margin-bottom:22px;font-size:25px;font-weight:800;letter-spacing:-.5px}
.logo{width:42px;height:42px;border-radius:11px;background:var(--brand);display:grid;place-items:center;font-size:23px;box-shadow:0 6px 16px rgba(249,115,22,.35)}
.card{width:100%;max-width:460px;background:var(--card);border-radius:20px;padding:38px 32px 30px;box-shadow:0 14px 44px rgba(0,0,0,.10);border-top:5px solid var(--brand);text-align:center}
.icon{width:76px;height:76px;border-radius:50%;display:grid;place-items:center;margin:0 auto 20px}
.t-success .icon{background:var(--ok-bg);color:var(--ok)}.t-error .icon{background:var(--err-bg);color:var(--err)}
.t-info .icon{background:var(--info-bg);color:var(--info)}.t-warning .icon{background:var(--warn-bg);color:var(--warn)}
h1{margin:0 0 10px;font-size:25px;line-height:1.25;letter-spacing:-.3px}
p{margin:0 0 12px;line-height:1.65;color:var(--muted);font-size:16px}
.small{font-size:13.5px;color:var(--soft)}
.btn{display:inline-block;margin-top:10px;padding:14px 26px;border:0;border-radius:11px;background:var(--brand);color:#fff;font-weight:700;font-size:16px;text-decoration:none;cursor:pointer;width:100%}
.btn:hover{background:var(--brand-d)}.btn:disabled{opacity:.6;cursor:not-allowed}
form{text-align:left;margin-top:14px}
label{display:block;font-size:13.5px;font-weight:600;margin:14px 0 6px}
.field{position:relative}
input{width:100%;padding:13px 14px;border-radius:10px;border:1.5px solid var(--line);background:var(--field);color:var(--ink);font-size:16px;outline:none}
input:focus{border-color:var(--brand);box-shadow:0 0 0 3px rgba(249,115,22,.18)}
.eye{position:absolute;right:6px;top:50%;transform:translateY(-50%);border:0;background:none;color:var(--soft);padding:8px 10px;cursor:pointer;font-size:13px;font-weight:600}
.msg{margin-top:12px;font-size:14px;min-height:20px;text-align:center}.msg.bad{color:var(--err)}.msg.good{color:var(--ok)}
.meter{height:5px;border-radius:3px;background:var(--line);margin-top:8px;overflow:hidden}.meter i{display:block;height:100%;width:0;background:var(--err);transition:width .2s,background .2s}
table.rec{width:100%;border-collapse:collapse;margin:16px 0 4px;text-align:left}
.rec td{padding:10px 0;border-bottom:1px solid var(--line);font-size:14.5px;color:var(--soft)}.rec td:last-child{text-align:right;color:var(--ink);font-weight:700}
.foot{margin-top:22px;font-size:12.5px;color:var(--soft);text-align:center}
</style>
</head>
<body>
<div class="brand"><div class="logo">&#128214;</div>ReadIn</div>
<main class="card t-${o.tone}">
  <div class="icon">${ICONS[o.tone]}</div>
  <h1>${esc(o.heading)}</h1>
  <p>${o.message}</p>
  ${o.extra ?? ''}
</main>
<div class="foot">&copy; ${new Date().getFullYear()} ReadIn &middot; Your personal reading platform</div>
${o.script ? `<script>${o.script}</script>` : ''}
</body>
</html>`

// ── verify e-mail ──────────────────────────────────────────────────────────────

export type VerifyResult = 'ok' | 'already' | 'expired' | 'invalid'

export const verifyEmailPage = (result: VerifyResult): string => {
  if (result === 'ok' || result === 'already') {
    return renderPage({
      title: 'E-mail confirmed',
      tone: 'success',
      heading: result === 'ok' ? 'E-mail confirmed!' : 'Already confirmed',
      message:
        result === 'ok'
          ? 'Your ReadIn account is active. Go back to the <strong>ReadIn app</strong> and sign in with your e-mail and password.'
          : 'This e-mail address was already confirmed. You can sign in to the <strong>ReadIn app</strong>.',
      extra: '<p class="small">You can close this page now.</p>',
    })
  }
  const text =
    result === 'expired'
      ? 'This confirmation link has expired (links work for 24 hours). Enter your e-mail and we will send you a new one.'
      : 'This confirmation link is not valid. It may already have been replaced by a newer one. Enter your e-mail and we will send you a new link.'
  return renderPage({
    title: 'Link expired',
    tone: 'warning',
    heading: result === 'expired' ? 'This link has expired' : 'This link is not valid',
    message: esc(text),
    extra: `<form id="f"><label for="e">Your e-mail address</label><div class="field"><input id="e" type="email" autocomplete="email" required placeholder="you@example.com"></div>
<button class="btn" id="b" type="submit">Send me a new link</button><div class="msg" id="m"></div></form>`,
    script: `
var f=document.getElementById('f'),m=document.getElementById('m'),b=document.getElementById('b');
f.addEventListener('submit',function(ev){ev.preventDefault();b.disabled=true;m.className='msg';m.textContent='Sending…';
fetch('/api/v1/auth/resend-verification',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:document.getElementById('e').value})})
.then(function(r){return r.json().catch(function(){return{}})}).then(function(j){m.className='msg good';m.textContent=(j&&j.message)||'If that account needs confirming, a new link is on its way.';})
.catch(function(){b.disabled=false;m.className='msg bad';m.textContent='Could not send. Check your connection and try again.'})});`,
  })
}

// ── reset password ─────────────────────────────────────────────────────────────

export const resetPasswordPage = (token: string): string =>
  renderPage({
    title: 'Choose a new password',
    tone: 'info',
    heading: 'Choose a new password',
    message: 'Pick something you do not use anywhere else. At least 8 characters.',
    extra: `<form id="f" novalidate>
<label for="p1">New password</label>
<div class="field"><input id="p1" type="password" autocomplete="new-password" minlength="8" required><button class="eye" type="button" id="eye">Show</button></div>
<div class="meter"><i id="bar"></i></div>
<label for="p2">Repeat password</label>
<div class="field"><input id="p2" type="password" autocomplete="new-password" minlength="8" required></div>
<button class="btn" id="b" type="submit">Save new password</button>
<div class="msg" id="m"></div></form>`,
    script: `
var TOKEN=${JSON.stringify(token).replace(/</g, '\\u003c')};
var p1=document.getElementById('p1'),p2=document.getElementById('p2'),m=document.getElementById('m'),b=document.getElementById('b'),bar=document.getElementById('bar'),card=document.querySelector('.card');
document.getElementById('eye').addEventListener('click',function(){var s=p1.type==='password';p1.type=p2.type=s?'text':'password';this.textContent=s?'Hide':'Show'});
p1.addEventListener('input',function(){var v=p1.value,s=0;if(v.length>=8)s++;if(v.length>=12)s++;if(/[A-Z]/.test(v)&&/[a-z]/.test(v))s++;if(/\\d/.test(v))s++;if(/[^A-Za-z0-9]/.test(v))s++;
bar.style.width=(s*20)+'%';bar.style.background=s<=2?'#dc2626':s<=3?'#d97706':'#16a34a'});
document.getElementById('f').addEventListener('submit',function(ev){ev.preventDefault();m.className='msg bad';
if(p1.value.length<8){m.textContent='Use at least 8 characters.';return}
if(p1.value!==p2.value){m.textContent='The two passwords do not match.';return}
b.disabled=true;m.className='msg';m.textContent='Saving…';
fetch('/api/v1/auth/reset-password',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({token:TOKEN,password:p1.value})})
.then(function(r){return r.json().catch(function(){return{}}).then(function(j){return{ok:r.ok,j:j}})})
.then(function(x){if(x.ok){card.className='card t-success';card.innerHTML='<div class="icon"><svg viewBox="0 0 24 24" width="38" height="38" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.2 4.2L19 7"/></svg></div><h1>Password changed</h1><p>Your password was updated and you were signed out everywhere. Open the <strong>ReadIn app</strong> and sign in with your new password.</p><p class="small">You can close this page now.</p>';}
else{b.disabled=false;m.className='msg bad';m.textContent=(x.j&&x.j.message)||'Could not change the password.'}})
.catch(function(){b.disabled=false;m.className='msg bad';m.textContent='Could not reach the server. Try again.'})});`,
  })

export const resetInvalidPage = (): string =>
  renderPage({
    title: 'Link expired',
    tone: 'warning',
    heading: 'This reset link is not valid',
    message:
      'Password reset links work for <strong>1 hour</strong> and only once. Open the ReadIn app, tap <strong>Forgot password</strong> and we will send you a new link.',
  })

// ── payment result (after Paystack) ────────────────────────────────────────────

export interface PaymentPageInput {
  status: 'success' | 'pending' | 'failed' | 'unknown' | 'error'
  planName?: string
  amountText?: string
  reference?: string
  premiumUntilText?: string
  reason?: string
}

export const paymentResultPage = (p: PaymentPageInput): string => {
  const rows = (items: Array<[string, string]>): string =>
    `<table class="rec">${items.map(([k, v]) => `<tr><td>${esc(k)}</td><td>${esc(v)}</td></tr>`).join('')}</table>`
  if (p.status === 'success') {
    return renderPage({
      title: 'Payment successful',
      tone: 'success',
      heading: 'Payment successful',
      message: 'Thank you! <strong>ReadIn Premium</strong> is now active on your account. Return to the app — it updates by itself.',
      extra:
        rows([
          ['Plan', p.planName ?? '—'],
          ['Amount', p.amountText ?? '—'],
          ['Active until', p.premiumUntilText ?? '—'],
          ['Reference', p.reference ?? '—'],
        ]) + '<p class="small">A receipt was sent to your e-mail. You can close this page.</p>',
    })
  }
  if (p.status === 'pending') {
    return renderPage({
      title: 'Payment processing',
      tone: 'info',
      heading: 'Payment is processing',
      message: 'Your bank has not confirmed the payment yet. This can take a minute. Return to the app and pull to refresh — Premium will activate by itself once it is confirmed.',
      extra: p.reference ? rows([['Reference', p.reference]]) : '',
    })
  }
  if (p.status === 'failed') {
    return renderPage({
      title: 'Payment not completed',
      tone: 'error',
      heading: 'Payment was not completed',
      message: `${esc(p.reason ?? 'The payment did not go through.')} You have not been charged. Return to the app and try again.`,
      extra: p.reference ? rows([['Reference', p.reference]]) : '',
    })
  }
  return renderPage({
    title: 'Payment status unknown',
    tone: 'warning',
    heading: p.status === 'unknown' ? 'We could not find this payment' : 'We could not check this payment',
    message:
      p.status === 'unknown'
        ? 'This payment reference is not known. If money left your account, contact support with your reference.'
        : 'We could not reach our payment provider right now. If you were charged, Premium will still activate automatically — check the app in a few minutes.',
    extra: p.reference ? rows([['Reference', p.reference]]) : '',
  })
}

// ── generic ────────────────────────────────────────────────────────────────────

export const notFoundPage = (): string =>
  renderPage({
    title: 'Page not found',
    tone: 'warning',
    heading: 'Page not found',
    message: 'The page you are looking for does not exist or has moved.',
  })

export const landingPage = (): string =>
  renderPage({
    title: 'ReadIn',
    tone: 'info',
    heading: 'ReadIn is running',
    message: 'This is the ReadIn service. Open the <strong>ReadIn app</strong> on your phone to read.',
  })

export const errorPage = (): string =>
  renderPage({
    title: 'Something went wrong',
    tone: 'error',
    heading: 'Something went wrong',
    message: 'Please try again in a moment.',
  })
