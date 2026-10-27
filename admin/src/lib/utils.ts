import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

/** "12 Oct 2026, 14:05" in the viewer's locale. Call it after data has loaded (client only). */
export function formatDateTime(iso: string | null | undefined): string {
  if (!iso) return '—'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return '—'
  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(d)
}

export function formatDate(iso: string | null | undefined): string {
  if (!iso) return '—'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return '—'
  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(d)
}

/** "₦1,500" / "₦1,500.50" from kobo. */
export function formatNaira(kobo: number): string {
  const naira = Math.floor(kobo / 100)
  const rest = kobo % 100
  const whole = naira.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')
  return `₦${whole}${rest ? `.${rest.toString().padStart(2, '0')}` : ''}`
}

/** What the admin typed in the ₦ box → kobo (null if it is not a valid amount). */
export function nairaToKobo(input: string): number | null {
  const v = Number(input.replace(/,/g, '').trim())
  if (!Number.isFinite(v) || v <= 0) return null
  return Math.round(v * 100)
}
