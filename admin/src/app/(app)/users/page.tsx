'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { ChevronLeft, ChevronRight, Search } from 'lucide-react'
import { PlanBadge, StatusBadges } from '@/components/badges'
import { PageHeader } from '@/components/page-header'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Skeleton } from '@/components/ui/skeleton'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useApi } from '@/hooks/use-api'
import type { UsersPage } from '@/lib/types'
import { formatDate, formatDateTime } from '@/lib/utils'

const PAGE_SIZE = 20

export default function UsersPage() {
  const [input, setInput] = useState('')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)

  // wait until the typing pauses before searching
  useEffect(() => {
    const t = setTimeout(() => {
      setSearch(input.trim())
      setPage(1)
    }, 400)
    return () => clearTimeout(t)
  }, [input])

  const query = new URLSearchParams({ page: String(page), limit: String(PAGE_SIZE) })
  if (search) query.set('search', search)
  const { data, error, loading, reload } = useApi<UsersPage>(`users?${query.toString()}`)

  const totalPages = data ? Math.max(1, Math.ceil(data.total / data.limit)) : 1

  return (
    <>
      <PageHeader title="Users" description="Search accounts and open one to manage its plan and feature access." />

      <div className="relative mb-4 max-w-md">
        <Search className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          className="pl-9"
          placeholder="Search by e-mail or name…"
          value={input}
          onChange={(e) => setInput(e.target.value)}
        />
      </div>

      <Card className="py-2">
        <CardContent className="px-2">
          {error && !data ? (
            <div className="grid gap-3 p-6 text-center text-sm text-muted-foreground">
              {error}
              <Button variant="outline" size="sm" className="mx-auto" onClick={reload}>
                Try again
              </Button>
            </div>
          ) : !data ? (
            <div className="grid gap-2 p-4">
              {Array.from({ length: 6 }).map((_, i) => (
                <Skeleton key={i} className="h-9 w-full" />
              ))}
            </div>
          ) : data.items.length === 0 ? (
            <p className="p-6 text-center text-sm text-muted-foreground">No users found.</p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>E-mail</TableHead>
                  <TableHead>Name</TableHead>
                  <TableHead>Plan</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Joined</TableHead>
                  <TableHead>Last sign-in</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.items.map((u) => (
                  <TableRow key={u.id} className={loading ? 'opacity-60' : undefined}>
                    <TableCell>
                      <Link href={`/users/${u.id}`} className="font-medium hover:underline">
                        {u.email}
                      </Link>
                    </TableCell>
                    <TableCell className="max-w-48 truncate">{u.displayName}</TableCell>
                    <TableCell>
                      <PlanBadge plan={u.plan} />
                    </TableCell>
                    <TableCell>
                      <StatusBadges user={u} />
                    </TableCell>
                    <TableCell className="text-muted-foreground">{formatDate(u.createdAt)}</TableCell>
                    <TableCell className="text-muted-foreground">{formatDateTime(u.lastLoginAt)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {data && data.total > 0 && (
        <div className="mt-4 flex items-center justify-between text-sm text-muted-foreground">
          <span>
            {data.total.toLocaleString()} user{data.total === 1 ? '' : 's'} · page {data.page} of {totalPages}
          </span>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
              <ChevronLeft /> Previous
            </Button>
            <Button variant="outline" size="sm" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
              Next <ChevronRight />
            </Button>
          </div>
        </div>
      )}
    </>
  )
}
