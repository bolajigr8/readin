import { AppConfig } from '../models/appConfig.model.js'
import { mergeBilling, type BillingConfig } from './billing.logic.js'

let cache: { at: number; value: BillingConfig } | null = null

export const invalidateBillingConfig = (): void => {
  cache = null
}

/** Billing settings (admin-editable), cached for 15 s. */
export const getBillingConfig = async (): Promise<BillingConfig> => {
  if (cache && Date.now() - cache.at < 15_000) return cache.value
  const doc = await AppConfig.findOne({ key: 'features' }).lean()
  const value = mergeBilling(doc?.billing ?? null)
  cache = { at: Date.now(), value }
  return value
}
