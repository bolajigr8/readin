import Link from 'next/link'
import { ThemeToggle } from './theme-toggle'

const NAV = [
  { href: '/#features', label: 'Features' },
  { href: '/#how', label: 'How it works' },
  { href: '/#faq', label: 'Questions' },
]

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-50 border-b border-line bg-bg/75 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-4 px-5">
        <Link prefetch={false} href="/" className="flex items-center gap-2.5 font-semibold tracking-tight text-ink">
          {/* eslint-disable-next-line @next/next/no-img-element -- static export, tiny icon */}
          <img src="/img/icon-192.png" alt="" width={34} height={34} className="rounded-[10px] shadow-sm" />
          <span className="text-lg">ReadIn</span>
        </Link>
        <nav aria-label="Main" className="hidden items-center gap-7 text-sm text-muted md:flex">
          {NAV.map((n) => (
            <Link prefetch={false} key={n.href} href={n.href} className="transition hover:text-ink">
              {n.label}
            </Link>
          ))}
        </nav>
        <div className="flex items-center gap-2.5">
          <ThemeToggle />
          <Link prefetch={false}
            href="/#get"
            className="hidden rounded-full bg-ink px-4 py-2 text-sm font-medium text-bg transition hover:opacity-90 sm:inline-block"
          >
            Get the app
          </Link>
        </div>
      </div>
    </header>
  )
}
