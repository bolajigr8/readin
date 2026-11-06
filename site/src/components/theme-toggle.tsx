'use client'

import { Moon, Sun } from 'lucide-react'
import { useEffect, useState } from 'react'

/** Light / dark switch. The choice is remembered on this device (localStorage only). */
export function ThemeToggle() {
  const [dark, setDark] = useState<boolean | null>(null)

  useEffect(() => {
    // The inline script in layout.tsx already set the class before the first paint.
    // eslint-disable-next-line react-hooks/set-state-in-effect -- read the class once after mount
    setDark(document.documentElement.classList.contains('dark'))
  }, [])

  const toggle = () => {
    const next = !document.documentElement.classList.contains('dark')
    document.documentElement.classList.toggle('dark', next)
    try {
      localStorage.setItem('readin-theme', next ? 'dark' : 'light')
    } catch {
      /* private mode: the switch still works for this visit */
    }
    setDark(next)
  }

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={dark ? 'Switch to light mode' : 'Switch to dark mode'}
      title={dark ? 'Light mode' : 'Dark mode'}
      className="grid h-10 w-10 place-items-center rounded-full border border-line bg-card text-ink transition hover:scale-105 hover:border-brand/50"
    >
      {dark === null ? (
        <span className="h-4 w-4" />
      ) : dark ? (
        <Sun className="h-[18px] w-[18px]" />
      ) : (
        <Moon className="h-[18px] w-[18px]" />
      )}
    </button>
  )
}
