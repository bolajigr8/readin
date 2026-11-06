import { Lock, ShieldCheck, Trash2 } from 'lucide-react'
import Link from 'next/link'
import { DownloadButtons } from './download-buttons'
import { Reveal } from './reveal'
import { SUPPORT_EMAIL } from './site-footer'

const STEPS = [
  { n: '01', title: 'Install ReadIn', text: 'Get it from Google Play (coming soon) and create your free account.' },
  { n: '02', title: 'Add your books', text: 'Import EPUBs, PDFs and documents, or pick a free classic in Discover.' },
  { n: '03', title: 'Read your way', text: 'Choose your style, set a daily goal and let ReadIn keep your place.' },
]

export function HowItWorks() {
  return (
    <section id="how" className="scroll-mt-20 border-y border-line bg-bg-2/50 py-24">
      <div className="mx-auto max-w-6xl px-5">
        <Reveal className="max-w-2xl">
          <p className="text-sm font-semibold uppercase tracking-[0.2em] text-brand">How it works</p>
          <h2 className="mt-3 font-serif text-4xl font-semibold tracking-tight text-ink sm:text-5xl">
            Reading in <span className="italic text-gradient">three</span> simple steps
          </h2>
        </Reveal>
        <div className="relative mt-14 grid gap-6 md:grid-cols-3">
          <div className="absolute left-0 right-0 top-9 hidden h-px bg-gradient-to-r from-transparent via-brand/40 to-transparent md:block" aria-hidden="true" />
          {STEPS.map((s, i) => (
            <Reveal key={s.n} delay={i * 0.12} className="relative rounded-3xl border border-line bg-card p-7">
              <div className="grid h-12 w-12 place-items-center rounded-2xl bg-ink font-serif text-lg font-semibold text-bg">{s.n}</div>
              <h3 className="mt-5 font-serif text-2xl font-semibold text-ink">{s.title}</h3>
              <p className="mt-2 leading-relaxed text-muted">{s.text}</p>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  )
}

export function Privacy() {
  const points = [
    { icon: ShieldCheck, title: 'No ads. No tracking.', text: 'We never sell your data or show ads.' },
    { icon: Lock, title: 'Your books stay yours', text: 'Imported books live on your phone. Only your library list, notes and progress sync to your account.' },
    { icon: Trash2, title: 'Leave any time', text: 'Delete your account and data in the app or on the web, whenever you want.' },
  ]
  return (
    <section className="py-24">
      <div className="mx-auto grid max-w-6xl items-center gap-12 px-5 lg:grid-cols-2">
        <Reveal>
          <p className="text-sm font-semibold uppercase tracking-[0.2em] text-brand">Private by design</p>
          <h2 className="mt-3 font-serif text-4xl font-semibold tracking-tight text-ink sm:text-5xl">
            A quiet place to read, <span className="italic text-gradient">just for you</span>
          </h2>
          <p className="mt-5 max-w-lg leading-relaxed text-muted">
            Reading is personal. ReadIn keeps only what it needs to sync your library across phones — nothing more.{' '}
            <Link prefetch={false} href="/privacy" className="font-medium text-brand underline underline-offset-4">Read our privacy policy</Link>.
          </p>
        </Reveal>
        <div className="grid gap-4">
          {points.map((p, i) => (
            <Reveal key={p.title} delay={i * 0.1} className="flex gap-4 rounded-3xl border border-line bg-card p-6">
              <div className="grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-brand/12 text-brand">
                <p.icon className="h-5 w-5" />
              </div>
              <div>
                <h3 className="font-semibold text-ink">{p.title}</h3>
                <p className="mt-1 text-muted">{p.text}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  )
}

const FAQ = [
  { q: 'Is ReadIn free?', a: 'Yes. Reading, free classics, notes and highlights are free. ReadIn Premium adds unlimited books in your library and extra features such as the reading habit tracker.' },
  { q: 'Do my books leave my phone?', a: 'Books you import are stored on your phone. Your library list, notes, highlights and progress sync to your account so you never lose them.' },
  { q: 'Which phones are supported?', a: 'Android 7.0 or newer.' },
  { q: 'Does it work offline?', a: 'Yes. Books on your phone open without internet. You only need a connection to sign in, sync and download new classics.' },
  { q: 'How do I delete my account?', a: 'In the app: Profile → Delete account. Without the app: use the delete-account page on this website.' },
]

export function Faq() {
  return (
    <section id="faq" className="scroll-mt-20 border-t border-line py-24">
      <div className="mx-auto max-w-3xl px-5">
        <Reveal className="text-center">
          <p className="text-sm font-semibold uppercase tracking-[0.2em] text-brand">Questions</p>
          <h2 className="mt-3 font-serif text-4xl font-semibold tracking-tight text-ink sm:text-5xl">Good to know</h2>
        </Reveal>
        <div className="mt-12 space-y-3">
          {FAQ.map((f, i) => (
            <Reveal key={f.q} delay={i * 0.05}>
              <details className="group rounded-2xl border border-line bg-card px-6 py-5 open:shadow-[var(--shadow)]">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-4 font-semibold text-ink">
                  {f.q}
                  <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full border border-line text-brand transition group-open:rotate-45">+</span>
                </summary>
                <p className="mt-3 leading-relaxed text-muted">
                  {f.a}{' '}
                  {f.q.startsWith('How do I delete') ? (
                    <Link prefetch={false} href="/delete-account" className="text-brand underline underline-offset-4">Delete-account page</Link>
                  ) : null}
                </p>
              </details>
            </Reveal>
          ))}
          <p className="pt-4 text-center text-muted">
            Something else? <a href={`mailto:${SUPPORT_EMAIL}`} className="font-medium text-brand underline underline-offset-4">{SUPPORT_EMAIL}</a>
          </p>
        </div>
      </div>
    </section>
  )
}

export function FinalCta() {
  return (
    <section className="px-5 pb-24">
      <Reveal className="relative mx-auto max-w-6xl overflow-hidden rounded-[2.5rem] bg-ink px-6 py-16 text-center sm:px-12 sm:py-20">
        <div className="blob -left-20 -top-20 h-72 w-72 bg-brand/40" aria-hidden="true" />
        <div className="blob -bottom-24 -right-16 h-72 w-72 bg-amber/30" aria-hidden="true" />
        <div className="relative">
          <h2 className="font-serif text-4xl font-semibold tracking-tight text-bg sm:text-6xl">
            Your next chapter <span className="italic text-gradient">starts here</span>
          </h2>
          <p className="mx-auto mt-5 max-w-xl text-lg text-bg/70">
            Join the readers getting ReadIn first. Calm, beautiful and made for everyday reading.
          </p>
          <div className="mt-10 [&_#cta-release-note]:text-bg/60">
            <DownloadButtonsOnDark />
          </div>
        </div>
      </Reveal>
    </section>
  )
}

/** The CTA band is dark in light mode (and light in dark mode) — reuse the buttons, centred. */
function DownloadButtonsOnDark() {
  return <DownloadButtons align="center" idPrefix="cta-" inverse />
}
