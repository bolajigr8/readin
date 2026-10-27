'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useParams } from 'next/navigation'
import { ArrowLeft, Ban, CalendarPlus, Loader2, MailCheck, RotateCcw, ShieldCheck, Undo2 } from 'lucide-react'
import { toast } from 'sonner'
import { AccessBadge, PlanBadge, StatusBadges } from '@/components/badges'
import { Explain } from '@/components/help'
import { PageHeader } from '@/components/page-header'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Separator } from '@/components/ui/separator'
import { Skeleton } from '@/components/ui/skeleton'
import { Switch } from '@/components/ui/switch'
import { useApi } from '@/hooks/use-api'
import { api } from '@/lib/api'
import { FEATURE_LABELS, type UserDetail } from '@/lib/types'
import { formatDateTime } from '@/lib/utils'

type Pending =
  | { kind: 'grant'; feature: string }
  | { kind: 'revoke'; feature: string }
  | { kind: 'disable' }
  | null

export default function UserDetailPage() {
  const params = useParams<{ id: string }>()
  const id = typeof params.id === 'string' ? params.id : ''
  const { data, error, reload } = useApi<UserDetail>(id ? `users/${id}` : null)

  const [busy, setBusy] = useState<string | null>(null)
  const [pending, setPending] = useState<Pending>(null)
  const [days, setDays] = useState('30')

  async function run(key: string, call: () => Promise<unknown>, success: string) {
    setBusy(key)
    try {
      await call()
      toast.success(success)
      reload()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Something went wrong.')
    } finally {
      setBusy(null)
      setPending(null)
    }
  }

  const feature = (key: string, action: 'grant' | 'revoke' | 'restore' | 'reset-trial', body?: unknown) =>
    api(`users/${id}/features/${key}/${action}`, { method: 'POST', body: body ?? {} })

  if (error && !data) {
    return (
      <>
        <BackLink />
        <p className="text-sm text-destructive">{error}</p>
      </>
    )
  }
  if (!data) {
    return (
      <>
        <BackLink />
        <Skeleton className="mb-4 h-8 w-64" />
        <Skeleton className="h-48 w-full" />
      </>
    )
  }

  const u = data.user
  const isAdmin = u.role === 'admin'
  const dayCount = Number(days)
  const daysValid = Number.isInteger(dayCount) && dayCount >= 1 && dayCount <= 3650

  return (
    <>
      <BackLink />
      <PageHeader
        title={u.email}
        description={u.displayName}
        actions={
          <div className="flex items-center gap-2">
            <PlanBadge plan={u.plan} />
            <StatusBadges user={u} />
          </div>
        }
      />

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Account</CardTitle>
            <CardDescription>Basic information.</CardDescription>
          </CardHeader>
          <CardContent className="grid gap-3 text-sm">
            <Row label="Joined" value={formatDateTime(u.createdAt)} />
            <Row label="Last sign-in" value={formatDateTime(u.lastLoginAt)} />
            <Row label="E-mail verified" value={u.isEmailVerified ? 'Yes' : 'No'} />
            {u.premiumUntil ? <Row label="Subscription period ends" value={formatDateTime(u.premiumUntil)} /> : null}
            <Row label="Books in library" value={String(data.books)} />
            <Row label="User id" value={<span className="font-mono text-xs">{u.id}</span>} />
            {!u.isEmailVerified && (
              <div className="grid gap-2 rounded-lg border border-amber-500/40 bg-amber-500/10 p-3">
                <p className="text-sm">This user has not confirmed their e-mail yet, so they cannot sign in.</p>
                <Button
                  size="sm"
                  className="w-fit"
                  disabled={busy !== null}
                  onClick={() => void run('verify', () => api(`users/${id}/verify`, { method: 'POST', body: {} }), 'E-mail marked as verified — they can sign in now.')}
                >
                  {busy === 'verify' ? <Loader2 className="animate-spin" /> : <MailCheck />} Verify e-mail now
                </Button>
                <Explain title="What does &ldquo;Verify e-mail now&rdquo; do?">
                  <p>It marks the address as confirmed <em>without</em> the user clicking the link in their e-mail. Use it when the e-mail never arrived (spam folder, typo-free but blocked), or for people you know personally. The user can sign in straight away. It is recorded in the Audit log.</p>
                  <p>It does <strong>not</strong> prove the address is really theirs &mdash; only do it for people you trust.</p>
                </Explain>
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Plan & access</CardTitle>
            <CardDescription>
              {isAdmin ? 'Administrator accounts can only be changed on the server.' : 'Changes apply immediately.'}
            </CardDescription>
          </CardHeader>
          <CardContent className="grid gap-4">
            <div className="flex items-center justify-between gap-4">
              <div>
                <Label htmlFor="premium">Premium plan</Label>
                <p className="text-xs text-muted-foreground">Premium users get every included feature without a trial.</p>
              </div>
              <Switch
                id="premium"
                checked={u.plan === 'premium'}
                disabled={isAdmin || busy !== null}
                onCheckedChange={(on) =>
                  run('plan', () => api(`users/${id}`, { method: 'PATCH', body: { plan: on ? 'premium' : 'free' } }), on ? 'Premium enabled.' : 'Switched to Free.')
                }
              />
            </div>
            <Separator />
            <div className="flex items-center justify-between gap-4">
              <div>
                <Label htmlFor="disabled">Account disabled</Label>
                <p className="text-xs text-muted-foreground">A disabled user cannot sign in and is signed out everywhere.</p>
              </div>
              <Switch
                id="disabled"
                checked={u.disabled}
                disabled={isAdmin || busy !== null}
                onCheckedChange={(on) => {
                  if (on) setPending({ kind: 'disable' })
                  else run('disabled', () => api(`users/${id}`, { method: 'PATCH', body: { disabled: false } }), 'Account enabled.')
                }}
              />
            </div>
            <Explain>
              <p><strong>Premium plan:</strong> switching it on gives this user Premium <em>with no end date</em> (a gift that lasts until you switch it off). People who pay through Paystack get Premium for the days of their plan and it ends by itself &mdash; the &ldquo;Subscription period ends&rdquo; row in Account shows that date.</p>
              <p><strong>Account disabled:</strong> the user is signed out on every device and cannot sign in or use the app until you enable the account again. Their data is kept.</p>
            </Explain>
          </CardContent>
        </Card>
      </div>

      <h2 className="mt-8 mb-3 text-lg font-semibold">Feature access</h2>
      <div className="grid gap-4">
        {Object.entries(data.features).map(([key, f]) => {
          const label = FEATURE_LABELS[key] ?? { name: key, description: '' }
          return (
            <Card key={key}>
              <CardHeader className="flex-row items-start justify-between gap-4">
                <div className="grid gap-1.5">
                  <CardTitle>{label.name}</CardTitle>
                  <CardDescription>{label.description}</CardDescription>
                </div>
                <AccessBadge state={f.state} />
              </CardHeader>
              <CardContent className="grid gap-4">
                <div className="grid gap-3 text-sm sm:grid-cols-2">
                  <Row label="Status" value={f.reason || '—'} />
                  <Row label="Trial started" value={formatDateTime(f.trialStartedAt)} />
                  <Row label="Trial ends" value={formatDateTime(f.trialEndsAt)} />
                  <Row label="Days left" value={f.daysLeft === null ? '—' : String(f.daysLeft)} />
                  <Row label="Gift until" value={formatDateTime(f.grantedUntil)} />
                  <Row label="Blocked by admin" value={f.revoked ? 'Yes' : 'No'} />
                </div>
                <div className="flex flex-wrap gap-2">
                  <Button size="sm" onClick={() => setPending({ kind: 'grant', feature: key })} disabled={busy !== null}>
                    <CalendarPlus /> Grant access…
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    disabled={busy !== null}
                    onClick={() => run(`reset-${key}`, () => feature(key, 'reset-trial'), 'Trial reset — it starts again the next time they open the feature.')}
                  >
                    {busy === `reset-${key}` ? <Loader2 className="animate-spin" /> : <RotateCcw />} Reset trial
                  </Button>
                  {f.revoked || f.grantedUntil ? (
                    <Button
                      size="sm"
                      variant="outline"
                      disabled={busy !== null}
                      onClick={() => run(`restore-${key}`, () => feature(key, 'restore'), 'Back to normal rules.')}
                    >
                      <Undo2 /> Remove block / gift
                    </Button>
                  ) : null}
                  <Button
                    size="sm"
                    variant="destructive"
                    disabled={busy !== null || f.revoked}
                    onClick={() => setPending({ kind: 'revoke', feature: key })}
                  >
                    <Ban /> Block access…
                  </Button>
                </div>
                <Explain title="What do these buttons do?">
                  <p><strong>Grant access…</strong> gives this user the feature for free for the number of days you choose (a gift). It adds to any gift still running. Use it to say thanks, fix a complaint, or extend one person&rsquo;s trial.</p>
                  <p><strong>Reset trial</strong> forgets that the trial was used. The user gets a fresh trial (of the length set on the Features page) the next time they open the feature.</p>
                  <p><strong>Block access…</strong> removes the feature from this user immediately, even if they pay for Premium. Their data stays saved. Use it for abuse.</p>
                  <p><strong>Remove block / gift</strong> undoes a block or a gift, so the normal rules (trial / Premium) apply again.</p>
                </Explain>
              </CardContent>
            </Card>
          )
        })}
      </div>

      {/* grant */}
      <Dialog open={pending?.kind === 'grant'} onOpenChange={(o) => !o && setPending(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Grant full access</DialogTitle>
            <DialogDescription>
              The user gets this feature for free for the number of days below (added to any gift still running).
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-2">
            <Label htmlFor="days">Days (1 – 3650)</Label>
            <Input id="days" type="number" min={1} max={3650} value={days} onChange={(e) => setDays(e.target.value)} />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPending(null)}>
              Cancel
            </Button>
            <Button
              disabled={!daysValid || busy !== null}
              onClick={() => {
                if (pending?.kind !== 'grant') return
                const f = pending.feature
                void run(`grant-${f}`, () => feature(f, 'grant', { days: dayCount }), `Granted ${dayCount} days.`)
              }}
            >
              {busy?.startsWith('grant') && <Loader2 className="animate-spin" />}
              <ShieldCheck /> Grant
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* revoke */}
      <Dialog open={pending?.kind === 'revoke'} onOpenChange={(o) => !o && setPending(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Block access?</DialogTitle>
            <DialogDescription>
              {u.email} will lose this feature immediately, even if they are Premium. Their data is kept. You can remove the block later.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPending(null)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              disabled={busy !== null}
              onClick={() => {
                if (pending?.kind !== 'revoke') return
                const f = pending.feature
                void run(`revoke-${f}`, () => feature(f, 'revoke'), 'Access blocked.')
              }}
            >
              Block access
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* disable */}
      <Dialog open={pending?.kind === 'disable'} onOpenChange={(o) => !o && setPending(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Disable this account?</DialogTitle>
            <DialogDescription>
              {u.email} will be signed out everywhere and cannot sign in until you enable the account again.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPending(null)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              disabled={busy !== null}
              onClick={() => void run('disabled', () => api(`users/${id}`, { method: 'PATCH', body: { disabled: true } }), 'Account disabled.')}
            >
              Disable account
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  )
}

function BackLink() {
  return (
    <Button asChild variant="ghost" size="sm" className="mb-3 -ml-3">
      <Link href="/users">
        <ArrowLeft /> All users
      </Link>
    </Button>
  )
}

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-4">
      <span className="text-muted-foreground">{label}</span>
      <span className="text-right">{value}</span>
    </div>
  )
}
