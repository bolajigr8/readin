'use client'

import { RefreshCw } from 'lucide-react'
import { PageHeader } from '@/components/page-header'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useApi } from '@/hooks/use-api'
import type { AuditItem } from '@/lib/types'
import { formatDateTime } from '@/lib/utils'

export default function AuditPage() {
  const { data, error, loading, reload } = useApi<{ items: AuditItem[] }>('audit?limit=100')

  return (
    <>
      <PageHeader
        title="Audit log"
        description="Every change made through the admin API: who, what, on which user, from which address."
        actions={
          <Button variant="outline" size="sm" onClick={reload} disabled={loading}>
            <RefreshCw className={loading ? 'animate-spin' : undefined} /> Refresh
          </Button>
        }
      />
      <Card className="py-2">
        <CardContent className="px-2">
          {error && !data ? (
            <p className="p-6 text-center text-sm text-destructive">{error}</p>
          ) : !data ? (
            <div className="grid gap-2 p-4">
              {Array.from({ length: 6 }).map((_, i) => (
                <Skeleton key={i} className="h-9 w-full" />
              ))}
            </div>
          ) : data.items.length === 0 ? (
            <p className="p-6 text-center text-sm text-muted-foreground">No admin actions recorded yet.</p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>When</TableHead>
                  <TableHead>Action</TableHead>
                  <TableHead>User</TableHead>
                  <TableHead>Details</TableHead>
                  <TableHead>IP</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.items.map((a) => (
                  <TableRow key={a.id}>
                    <TableCell className="text-muted-foreground">{formatDateTime(a.createdAt)}</TableCell>
                    <TableCell className="font-mono text-xs">{a.action}</TableCell>
                    <TableCell className="font-mono text-xs">{a.targetUserId ? a.targetUserId.slice(-8) : '—'}</TableCell>
                    <TableCell className="max-w-xs truncate font-mono text-xs text-muted-foreground">
                      {a.details === null || a.details === undefined ? '—' : JSON.stringify(a.details)}
                    </TableCell>
                    <TableCell className="font-mono text-xs text-muted-foreground">{a.ip || '—'}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </>
  )
}
