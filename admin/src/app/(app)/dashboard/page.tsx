'use client'

import Link from 'next/link'
import { Banknote, BookMarked, BookOpen, CalendarCheck, Crown, Receipt, RefreshCw, UserPlus, UserX, Users } from 'lucide-react'
import { useStats } from '@/components/app-shell'
import { PageHeader } from '@/components/page-header'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useApi } from '@/hooks/use-api'
import type { AuditItem } from '@/lib/types'
import { formatDateTime, formatNaira } from '@/lib/utils'

export default function DashboardPage() {
  const { stats, reloadStats } = useStats()
  const audit = useApi<{ items: AuditItem[] }>('audit?limit=8')

  const cards = [
    { label: 'Users', value: stats?.users, icon: Users },
    { label: 'Premium', value: stats?.premium, icon: Crown },
    { label: 'New this week', value: stats?.newThisWeek, icon: UserPlus },
    { label: 'Disabled', value: stats?.disabled, icon: UserX },
    { label: 'Books in libraries', value: stats?.books, icon: BookOpen },
    { label: 'Habit trials started', value: stats?.habitsTrialsStarted, icon: CalendarCheck },
  ]
  const money = [
    { label: 'Revenue this month', value: stats ? formatNaira(stats.revenueMonthKobo) : undefined, icon: Banknote },
    { label: 'Revenue, all time', value: stats ? formatNaira(stats.revenueKobo) : undefined, icon: Banknote },
    { label: 'Successful payments', value: stats ? stats.paymentsCount.toLocaleString() : undefined, icon: Receipt },
  ]

  return (
    <>
      <PageHeader
        title="Dashboard"
        description="A quick look at ReadIn."
        actions={
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              reloadStats()
              audit.reload()
            }}
          >
            <RefreshCw /> Refresh
          </Button>
        }
      />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {cards.map((c) => (
          <Card key={c.label} className="gap-2 py-5">
            <CardHeader className="flex-row items-center justify-between">
              <CardDescription>{c.label}</CardDescription>
              <c.icon className="size-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              {c.value === undefined ? (
                <Skeleton className="h-8 w-16" />
              ) : (
                <div className="text-3xl font-semibold tabular-nums">{c.value.toLocaleString()}</div>
              )}
            </CardContent>
          </Card>
        ))}
      </div>

      <h2 className="mt-8 mb-3 text-lg font-semibold">Money</h2>
      <div className="grid gap-4 sm:grid-cols-3">
        {money.map((c) => (
          <Card key={c.label} className="gap-2 py-5">
            <CardHeader className="flex-row items-center justify-between">
              <CardDescription>{c.label}</CardDescription>
              <c.icon className="size-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              {c.value === undefined ? <Skeleton className="h-8 w-24" /> : <div className="text-3xl font-semibold tabular-nums">{c.value}</div>}
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="mt-6 grid gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Latest admin activity</CardTitle>
            <CardDescription>Every change made in this panel is recorded.</CardDescription>
          </CardHeader>
          <CardContent>
            {audit.loading && !audit.data ? (
              <Skeleton className="h-32 w-full" />
            ) : (audit.data?.items.length ?? 0) === 0 ? (
              <p className="text-sm text-muted-foreground">Nothing yet.</p>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>When</TableHead>
                    <TableHead>Action</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {audit.data?.items.map((a) => (
                    <TableRow key={a.id}>
                      <TableCell className="text-muted-foreground">{formatDateTime(a.createdAt)}</TableCell>
                      <TableCell className="font-mono text-xs">{a.action}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Shortcuts</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-2">
            <Button asChild variant="outline" className="justify-start">
              <Link href="/users">
                <Users /> Find a user
              </Link>
            </Button>
            <Button asChild variant="outline" className="justify-start">
              <Link href="/features">
                <BookMarked /> Trial & feature settings
              </Link>
            </Button>
          </CardContent>
        </Card>
      </div>
    </>
  )
}
