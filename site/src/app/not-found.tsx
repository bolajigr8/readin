import type { Metadata } from 'next'
import Link from 'next/link'
import { SiteFooter } from '@/components/site-footer'
import { SiteHeader } from '@/components/site-header'

export const metadata: Metadata = { title: 'Page not found', robots: { index: false } }

export default function NotFound() {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto flex max-w-xl flex-col items-center px-5 py-28 text-center">
        <p className="font-serif text-7xl font-semibold italic text-gradient">404</p>
        <h1 className="mt-4 font-serif text-3xl font-semibold text-ink">This page does not exist</h1>
        <p className="mt-3 text-muted">Maybe the link is old — like a book that went missing from the shelf.</p>
        <Link prefetch={false} href="/" className="mt-8 rounded-full bg-ink px-6 py-3 font-medium text-bg transition hover:opacity-90">
          Back to ReadIn
        </Link>
      </main>
      <SiteFooter />
    </>
  )
}
