import Link from 'next/link'

export const SUPPORT_EMAIL = 'micboltech@gmail.com'

export function SiteFooter() {
  return (
    <footer className="border-t border-line">
      <div className="mx-auto flex max-w-6xl flex-col gap-6 px-5 py-10 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-3">
          {/* eslint-disable-next-line @next/next/no-img-element -- static export, tiny icon */}
          <img src="/img/icon-192.png" alt="" width={30} height={30} className="rounded-lg" />
          <div>
            <div className="font-semibold text-ink">ReadIn</div>
            <div className="text-sm text-soft">© 2026 · readin.micbol.org</div>
          </div>
        </div>
        <nav aria-label="Legal" className="flex flex-wrap gap-x-6 gap-y-2 text-sm text-muted">
          <Link prefetch={false} href="/privacy" className="hover:text-ink">Privacy policy</Link>
          <Link prefetch={false} href="/terms" className="hover:text-ink">Terms of use</Link>
          <Link prefetch={false} href="/delete-account" className="hover:text-ink">Delete my account</Link>
          <a href={`mailto:${SUPPORT_EMAIL}`} className="hover:text-ink">Contact</a>
        </nav>
      </div>
    </footer>
  )
}
