import { fetchPrices } from '@/lib/prices'
import { PricingLive } from './pricing-live'

/**
 * Premium prices. Runs while the site is BUILT (static export): the prices at build time are written into the
 * page; the browser then refreshes them from the API. SITE_PRICES=off skips the build-time fetch (offline builds).
 */
export async function Pricing() {
  const initial = process.env['SITE_PRICES'] === 'off' ? null : ((await fetchPrices(70_000, true)) ?? null)
  return <PricingLive initial={initial} />
}
