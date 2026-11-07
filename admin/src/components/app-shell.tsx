'use client'

import { createContext, useContext, useState } from 'react'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { BookOpen, CircleHelp, CreditCard, LayoutDashboard, Loader2, LogOut, PackageCheck, RefreshCw, ScrollText, ShieldCheck, SlidersHorizontal, Users } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/skeleton'
import { useApi } from '@/hooks/use-api'
import type { AdminMe, Stats } from '@/lib/types'
import { cn } from '@/lib/utils'

interface StatsCtx {
  stats: Stats | undefined
  reloadStats: () => void
  /** The signed-in team member (role + permissions). */
  me: AdminMe | undefined
}

const StatsContext = createContext<StatsCtx | null>(null)

export function useStats(): StatsCtx {
  const ctx = useContext(StatsContext)
  if (!ctx) throw new Error('useStats must be used inside <AppShell>')
  return ctx
}

/** Can the signed-in person use this? (The server checks again on every request.) */
export function useCan(): (permission: string) => boolean {
  const ctx = useContext(StatsContext)
  return (p) => !!ctx?.me?.permissions.includes(p)
}

// `need` = the permission a page needs (S5); pages the person cannot use are hidden.
const NAV = [
  { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard, need: 'dashboard.read' },
  { href: '/users', label: 'Users', icon: Users, need: 'users.read' },
  { href: '/features', label: 'Features', icon: SlidersHorizontal, need: 'features.read' },
  { href: '/billing', label: 'Billing', icon: CreditCard, need: 'billing.read' },
  { href: '/releases', label: 'App versions', icon: PackageCheck, need: 'releases.write' },
  { href: '/team', label: 'Team', icon: ShieldCheck, need: 'team.manage' },
  { href: '/audit', label: 'Audit log', icon: ScrollText, need: 'audit.read' },
  { href: '/guide', label: 'Guide', icon: CircleHelp, need: null },
]

/**
 * Frame of every signed-in page. It also checks the session: the first request
 * (/me) is team-only, so a missing/expired session is detected here and
 * sends you to the sign-in page (see lib/api.ts).
 */
export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const { data, error, loading, reload } = useApi<AdminMe>('me')
  const stats = useApi<Stats>(data?.permissions.includes('dashboard.read') ? 'stats' : null)
  const nav = NAV.filter((n) => n.need === null || !!data?.permissions.includes(n.need))
  const here = NAV.find((n) => pathname === n.href || pathname.startsWith(n.href + '/'))
  const allowedHere = !here || here.need === null || !!data?.permissions.includes(here.need)
  const [signingOut, setSigningOut] = useState(false)

  async function signOut() {
    setSigningOut(true)
    try {
      await fetch('/api/auth/logout', {
        method: 'POST',
        headers: { 'x-requested-with': 'admin' },
        cache: 'no-store',
      })
    } finally {
      router.replace('/login')
    }
  }

  // Not reachable (asleep / network): show a retry instead of a blank page.
  if (!data && error) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-4 p-6 text-center">
        <p className="max-w-md text-sm text-muted-foreground">{error}</p>
        <Button onClick={reload}>
          <RefreshCw /> Try again
        </Button>
      </div>
    )
  }

  if (!data && loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="grid w-64 gap-3 text-center">
          <Loader2 className="mx-auto size-6 animate-spin text-primary" />
          <p className="text-sm text-muted-foreground">Connecting to the server…</p>
          <Skeleton className="h-2 w-full" />
        </div>
      </div>
    )
  }

  return (
    <StatsContext.Provider value={{ stats: stats.data, reloadStats: stats.reload, me: data }}>
      <div className="flex min-h-screen flex-col md:flex-row">
        <aside className="border-b bg-sidebar md:sticky md:top-0 md:h-screen md:w-56 md:shrink-0 md:border-r md:border-b-0">
          <div className="flex items-center gap-2 px-4 py-4">
            <div className="flex size-8 items-center justify-center rounded-lg bg-primary text-primary-foreground">
              <BookOpen className="size-4" />
            </div>
            <span className="font-semibold">ReadIn Admin</span>
          </div>
          <nav className="flex gap-1 overflow-x-auto px-2 pb-2 md:grid md:overflow-visible">
            {nav.map((item) => {
              const active = pathname === item.href || pathname.startsWith(item.href + '/')
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={cn(
                    'flex items-center gap-2 rounded-md px-3 py-2 text-sm whitespace-nowrap transition-colors hover:bg-accent',
                    active && 'bg-accent font-medium text-accent-foreground',
                  )}
                >
                  <item.icon className="size-4" />
                  {item.label}
                </Link>
              )
            })}
          </nav>
          <div className="hidden px-2 md:absolute md:right-0 md:bottom-4 md:left-0 md:block">
            <Button variant="ghost" className="w-full justify-start" onClick={signOut} disabled={signingOut}>
              {signingOut ? <Loader2 className="animate-spin" /> : <LogOut />} Sign out
            </Button>
          </div>
        </aside>

        <div className="flex min-w-0 flex-1 flex-col">
          <header className="flex items-center justify-end border-b px-4 py-2 md:hidden">
            <Button variant="ghost" size="sm" onClick={signOut} disabled={signingOut}>
              <LogOut /> Sign out
            </Button>
          </header>
          <main className="mx-auto w-full max-w-6xl flex-1 p-4 md:p-8">
            {allowedHere ? (
              children
            ) : (
              <div className="mx-auto mt-16 grid max-w-md gap-3 text-center">
                <p className="text-lg font-semibold">You don&rsquo;t have permission for this page</p>
                <p className="text-sm text-muted-foreground">
                  Ask an owner of ReadIn to give you access on the Team page. You can use:{' '}
                  {nav.map((n) => n.label).join(', ')}.
                </p>
                {nav[0] && (
                  <Button className="mx-auto w-fit" onClick={() => router.replace(nav[0]!.href)}>
                    Open {nav[0].label}
                  </Button>
                )}
              </div>
            )}
          </main>
        </div>
      </div>
    </StatsContext.Provider>
  )
}
