'use client'

import { motion } from 'motion/react'
import { Flame, Headphones, Highlighter } from 'lucide-react'

/**
 * A phone showing the ReadIn reader, drawn with HTML/CSS (sharp at any size, no screenshots to
 * keep up to date). The text is the public-domain opening of "Pride and Prejudice".
 */
export function PhoneMockup() {
  return (
    <div className="relative mx-auto w-full max-w-[280px] sm:max-w-[300px]">
      {/* glow under the phone */}
      <div className="absolute -inset-10 -z-10 rounded-full bg-[var(--glow)] blur-3xl" />

      <motion.div
        initial={{ opacity: 0, y: 40, rotate: -2 }}
        animate={{ opacity: 1, y: 0, rotate: -2 }}
        transition={{ duration: 0.9, ease: [0.22, 1, 0.36, 1], delay: 0.15 }}
        className="relative rounded-[2.6rem] border border-line bg-[#1a1411] p-2.5 shadow-[var(--shadow)]"
      >
        <div className="overflow-hidden rounded-[2.1rem] bg-[#fbf3e6] text-[#3b2a1e]">
          {/* status + reader bar */}
          <div className="flex items-center justify-between px-6 pt-3 text-[10px] font-semibold text-[#8a6f5a]">
            <span>9:41</span>
            <span className="h-4 w-16 rounded-full bg-[#1a1411]" />
            <span>100%</span>
          </div>
          <div className="flex items-center justify-between px-5 pb-2 pt-3 text-[11px] text-[#8a6f5a]">
            <span className="font-semibold">Pride and Prejudice</span>
            <span>Chapter 1</span>
          </div>
          {/* page */}
          <div className="px-5 pb-4 font-serif text-[13.5px] leading-[1.75]">
            <p className="mb-3 text-xl font-semibold italic leading-snug">Chapter 1</p>
            <p>
              It is a truth universally acknowledged, that a single man in possession of a good fortune,{' '}
              <span className="rounded bg-[#fcd9b4] px-0.5">must be in want of a wife.</span>
            </p>
            <p className="mt-3">
              However little known the feelings or views of such a man may be on his first entering a
              neighbourhood, this truth is so well fixed in the minds of the surrounding families…
            </p>
          </div>
          {/* progress */}
          <div className="px-5 pb-6">
            <div className="h-1 overflow-hidden rounded-full bg-[#ecdcc6]">
              <motion.div
                className="h-full rounded-full bg-[#f97316]"
                initial={{ width: '8%' }}
                animate={{ width: '34%' }}
                transition={{ duration: 2.2, delay: 0.8, ease: 'easeOut' }}
              />
            </div>
            <div className="mt-2 flex justify-between text-[10px] text-[#8a6f5a]">
              <span>34% read</span>
              <span>12 min left in chapter</span>
            </div>
          </div>
        </div>
      </motion.div>

      {/* floating cards */}
      <FloatCard className="-left-8 -top-5 sm:-left-20 sm:top-2" delay={0.9} float={-8}>
        <Flame className="h-5 w-5 text-[#f97316]" />
        <div>
          <div className="text-xs font-semibold text-ink">12-day streak</div>
          <div className="text-[11px] text-soft">Goal: 20 pages a day</div>
        </div>
      </FloatCard>
      <FloatCard className="-right-8 top-60 sm:-right-24" delay={1.15} float={8}>
        <Highlighter className="h-5 w-5 text-[#f59e0b]" />
        <div>
          <div className="text-xs font-semibold text-ink">Highlight saved</div>
          <div className="text-[11px] text-soft">Synced to your notes</div>
        </div>
      </FloatCard>
      <FloatCard className="-left-10 bottom-10 sm:-left-14" delay={1.4} float={-6}>
        <Headphones className="h-5 w-5 text-[#f97316]" />
        <div className="flex items-end gap-[3px]" aria-hidden="true">
          {[0, 1, 2, 3, 4].map((i) => (
            <span key={i} className="sound-bar h-4 w-[3px] rounded-full bg-[#f97316]" style={{ animationDelay: `${i * 0.14}s` }} />
          ))}
        </div>
        <div className="text-xs font-semibold text-ink">Reading aloud</div>
      </FloatCard>
    </div>
  )
}

function FloatCard({
  children,
  className,
  delay,
  float,
}: {
  children: React.ReactNode
  className: string
  delay: number
  float: number
}) {
  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.85 }}
      animate={{ opacity: 1, scale: 1, y: [0, float, 0] }}
      transition={{
        opacity: { duration: 0.5, delay },
        scale: { duration: 0.5, delay },
        y: { duration: 5, delay: delay + 0.5, repeat: Infinity, ease: 'easeInOut' },
      }}
      className={`absolute z-10 flex items-center gap-2.5 rounded-2xl border border-line bg-card/90 px-3.5 py-2.5 shadow-[var(--shadow)] backdrop-blur-md ${className}`}
    >
      {children}
    </motion.div>
  )
}
