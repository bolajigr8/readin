'use client'

import { motion } from 'motion/react'
import { ShieldCheck, Sparkles, WifiOff } from 'lucide-react'
import { DownloadButtons } from './download-buttons'
import { PhoneMockup } from './phone-mockup'

const ease = [0.22, 1, 0.36, 1] as const

export function Hero() {
  return (
    <section className="relative overflow-hidden">
      {/* background: glowing blobs + dotted paper */}
      <div className="blob -left-32 -top-24 h-[420px] w-[420px] bg-[var(--glow)]" aria-hidden="true" />
      <div className="blob -right-24 top-40 h-[360px] w-[360px] bg-amber/20" aria-hidden="true" />
      <div className="dots absolute inset-0 -z-0" aria-hidden="true" />

      <div className="relative mx-auto grid max-w-6xl grid-cols-1 items-center gap-16 px-5 pb-20 pt-14 md:pt-20 lg:grid-cols-[1.1fr_0.9fr] lg:gap-10">
        <div>
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, ease }}
            className="inline-flex items-center gap-2 rounded-full border border-line bg-card/70 px-3.5 py-1.5 text-xs font-medium text-muted backdrop-blur"
          >
            <Sparkles className="h-3.5 w-3.5 text-brand" />
            Your personal reading space — made in Nigeria
          </motion.div>

          <motion.h1
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.08, ease }}
            className="mt-6 font-serif text-[2.7rem] font-semibold leading-[1.05] tracking-tight text-ink sm:text-6xl lg:text-[4.2rem]"
          >
            Fall in love with <span className="text-gradient italic">reading</span> again.
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.16, ease }}
            className="mt-6 max-w-xl text-lg leading-relaxed text-muted"
          >
            ReadIn brings your EPUBs, PDFs and documents into one calm, beautiful reader — with thousands of free
            classics, notes that never get lost, a gentle daily habit and a voice that reads to you.
          </motion.p>

          <motion.div
            id="get"
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.24, ease }}
            className="mt-9 scroll-mt-24"
          >
            <DownloadButtons />
          </motion.div>

          <motion.ul
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.8, delay: 0.5 }}
            className="mt-8 flex flex-wrap gap-x-6 gap-y-2 text-sm text-muted"
          >
            <li className="flex items-center gap-2"><ShieldCheck className="h-4 w-4 text-brand" /> No ads, no tracking</li>
            <li className="flex items-center gap-2"><WifiOff className="h-4 w-4 text-brand" /> Reads offline</li>
            <li className="flex items-center gap-2"><Sparkles className="h-4 w-4 text-brand" /> Free to start</li>
          </motion.ul>
        </div>

        <div className="min-w-0 px-8 sm:px-16 lg:px-0">
          <PhoneMockup />
        </div>
      </div>
    </section>
  )
}
