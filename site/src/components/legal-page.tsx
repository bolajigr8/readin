import { SiteFooter } from './site-footer'
import { SiteHeader } from './site-header'

/** Shared frame for Privacy, Terms and Delete account. */
export function LegalPage({ title, updated, children }: { title: string; updated: string; children: React.ReactNode }) {
  return (
    <>
      <SiteHeader />
      <main className="relative">
        <div className="dots pointer-events-none absolute inset-x-0 top-0 h-72" aria-hidden="true" />
        <article className="prose-legal relative mx-auto max-w-3xl px-5 pb-20 pt-14">
          <h1 className="font-serif text-4xl font-semibold tracking-tight text-ink sm:text-5xl">{title}</h1>
          <p className="!mt-3 text-sm !text-soft">{updated}</p>
          <div className="mt-8">{children}</div>
        </article>
      </main>
      <SiteFooter />
    </>
  )
}
