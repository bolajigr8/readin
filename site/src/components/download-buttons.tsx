'use client'

import { Download, Play } from 'lucide-react'
import { useEffect, useState } from 'react'

/** Shape of /public/release.json — edit that file for each release (no code change). */
interface Release {
  playUrl: string
  apk: { url: string; version: string; date: string; sizeMb: number; sha256: string }
}

/**
 * `idPrefix` keeps element ids unique when the buttons appear twice on a page (hero + final banner).
 * `inverse` = buttons sitting on the dark (`bg-ink`) banner.
 */
export function DownloadButtons({
  align = 'start',
  idPrefix = '',
  inverse = false,
}: {
  align?: 'start' | 'center'
  idPrefix?: string
  inverse?: boolean
}) {
  const [rel, setRel] = useState<Release | null>(null)

  useEffect(() => {
    let alive = true
    fetch('/release.json', { cache: 'no-store' })
      .then((r) => (r.ok ? (r.json() as Promise<Release>) : null))
      .then((j) => {
        if (alive && j) setRel(j)
      })
      .catch(() => {
        /* keep "coming soon" */
      })
    return () => {
      alive = false
    }
  }, [])

  const play = rel?.playUrl || ''
  const apk = rel?.apk?.url || ''
  const base =
    'group inline-flex min-w-[240px] items-center justify-center gap-3 rounded-2xl px-6 py-4 text-left font-semibold transition'
  const off = 'pointer-events-none opacity-85'

  return (
    <div className={align === 'center' ? 'flex flex-col items-center' : 'flex flex-col items-start'}>
      <div className={`flex flex-wrap gap-3 ${align === 'center' ? 'justify-center' : ''}`}>
        <a
          id={`${idPrefix}play-btn`}
          href={play || '#get'}
          aria-disabled={play ? undefined : 'true'}
          rel={play ? 'noopener' : undefined}
          className={`${base} ${inverse ? 'bg-bg text-ink' : 'bg-ink text-bg'} shadow-[var(--shadow)] hover:-translate-y-0.5 ${play ? '' : off}`}
        >
          <Play className="h-5 w-5 fill-current" />
          <span className="leading-tight">
            <span className="block text-[11px] font-medium uppercase tracking-wider opacity-70">
              {play ? 'Get it on' : 'Coming soon to'}
            </span>
            <span className="block text-base">Google Play</span>
          </span>
        </a>
        <a
          id={`${idPrefix}apk-btn`}
          href={apk || '#get'}
          aria-disabled={apk ? undefined : 'true'}
          className={`${base} border hover:-translate-y-0.5 hover:border-brand/50 ${inverse ? 'border-bg/25 bg-transparent text-bg' : 'border-line bg-card text-ink'} ${apk ? '' : off}`}
        >
          <Download className="h-5 w-5 text-brand" />
          <span className="leading-tight">
            <span className={`block text-[11px] font-medium uppercase tracking-wider ${inverse ? 'text-bg/60' : 'text-soft'}`}>
              {apk ? `Direct download${rel?.apk.version ? ` · v${rel.apk.version}` : ''}` : 'Coming soon'}
            </span>
            <span className="block text-base">Android download</span>
          </span>
        </a>
      </div>
      <p id={`${idPrefix}release-note`} className={`mt-3 text-sm text-soft ${align === 'center' ? 'text-center' : ''}`}>
        {apk ? (
          <>
            {[rel?.apk.sizeMb ? `${rel.apk.sizeMb} MB` : '', rel?.apk.date ? `released ${rel.apk.date}` : '']
              .filter(Boolean)
              .join(' · ')}
            {rel?.apk.sha256 ? <span className="mt-1 block break-all font-mono text-xs">SHA-256: {rel.apk.sha256}</span> : null}
          </>
        ) : play ? null : (
          'ReadIn is getting ready for Google Play. Check back soon!'
        )}
      </p>
    </div>
  )
}
