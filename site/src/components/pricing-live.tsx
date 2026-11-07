'use client'

import { useEffect, useState } from 'react'
import { Check, Gift } from 'lucide-react'
import { fetchPrices, type Prices } from '@/lib/prices'
import { Reveal } from './reveal'

const PERKS = ['Unlimited books in your library', 'Reading habit tracker with streaks', 'Every new Premium feature']

const cap = (s: string): string => (s ? s[0]!.toUpperCase() + s.slice(1) : s)

/** Shows the prices from the build, then quietly updates them from the live API (admin changes, no rebuild). */
export function PricingLive({ initial }: { initial: Prices | null }) {
  const [prices, setPrices] = useState<Prices | null>(initial)

  useEffect(() => {
    let alive = true
    void fetchPrices(20_000).then((live) => {
      if (!alive) return
      // Could not ask (undefined) → keep the build-time prices. A real answer wins, including "payments off" (null).
      if (live !== undefined) setPrices(live)
    })
    return () => {
      alive = false
    }
  }, [])

  if (!prices) return null
  const cheapest = prices.plans.reduce((a, b) => (b.periodText === 'a month' ? b : a), prices.plans[0]!)

  return (
    <section id="pricing" data-testid="pricing" className="scroll-mt-20 border-t border-line py-24">
      <div className="mx-auto max-w-6xl px-5">
        <Reveal className="mx-auto max-w-2xl text-center">
          <p className="text-sm font-semibold uppercase tracking-[0.2em] text-brand">Premium</p>
          <h2 className="mt-3 font-serif text-4xl font-semibold tracking-tight text-ink sm:text-5xl">
            Read without limits for{' '}
            <span className="italic text-gradient">{cheapest.perDayText || `${cheapest.priceText} ${cheapest.periodText}`}</span>
          </h2>
          <p className="mt-5 leading-relaxed text-muted">
            ReadIn is free to use. Premium unlocks everything else.
          </p>
        </Reveal>

        <div className="mx-auto mt-12 grid max-w-3xl gap-5 sm:grid-cols-2">
          {prices.plans.map((p, i) => (
            <Reveal
              key={p.id}
              delay={i * 0.1}
              className={`relative min-w-0 rounded-3xl border bg-card p-7 ${p.savingsText ? 'border-brand shadow-lg shadow-brand/10' : 'border-line'}`}
            >
              {p.badge && (
                <span className="absolute -top-3 left-7 rounded-full bg-brand px-3 py-1 text-xs font-bold text-white">{p.badge}</span>
              )}
              <h3 className="font-semibold text-ink">{p.name}</h3>
              <p className="mt-3 flex flex-wrap items-baseline gap-x-2">
                <span className="font-serif text-4xl font-semibold text-ink" data-testid="price">{p.priceText}</span>
                <span className="text-muted">{p.periodText}</span>
              </p>
              {p.perDayText && <p className="mt-1 text-sm font-medium text-muted">{cap(p.perDayText)}</p>}
              {p.savingsText && (
                <p className="mt-3 inline-block rounded-full bg-brand/12 px-3 py-1 text-sm font-semibold text-brand">{p.savingsText}</p>
              )}
              <ul className="mt-5 grid gap-2">
                {PERKS.map((perk) => (
                  <li key={perk} className="flex gap-2 text-sm text-muted">
                    <Check className="mt-0.5 h-4 w-4 shrink-0 text-brand" /> {perk}
                  </li>
                ))}
              </ul>
            </Reveal>
          ))}
        </div>

        <Reveal className="mx-auto mt-8 max-w-2xl text-center text-sm text-muted">
          {prices.trialDays > 0 && (
            <p className="mb-2 inline-flex items-center gap-2 font-medium text-ink">
              <Gift className="h-4 w-4 text-brand" /> New members can try Premium free for {prices.trialDays} days.
            </p>
          )}
          <p>Prices in Nigerian naira. You upgrade inside the app.</p>
        </Reveal>
      </div>
    </section>
  )
}
