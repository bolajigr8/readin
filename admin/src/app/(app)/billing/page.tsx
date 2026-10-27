'use client'

import { useState } from 'react'
import Link from 'next/link'
import { Check, Copy, CreditCard, Loader2, Plus, RefreshCw, Save, Trash2 } from 'lucide-react'
import { toast } from 'sonner'
import { Callout, Explain } from '@/components/help'
import { PageHeader } from '@/components/page-header'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Skeleton } from '@/components/ui/skeleton'
import { Switch } from '@/components/ui/switch'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useApi } from '@/hooks/use-api'
import { api } from '@/lib/api'
import type { AdminConfig, BillingConfig, BillingView, PaymentRow, PaymentsPage } from '@/lib/types'
import { formatDateTime, formatNaira, nairaToKobo } from '@/lib/utils'

export default function BillingPage() {
  const view = useApi<BillingView>('billing')
  const config = useApi<AdminConfig>('config')
  const payments = useApi<PaymentsPage>('payments?limit=15')

  const reloadAll = () => {
    view.reload()
    config.reload()
    payments.reload()
  }

  return (
    <>
      <PageHeader
        title="Billing & payments"
        description="Connect Paystack, set your prices in naira, and choose whether payments are visible in the app."
        actions={
          <Button variant="outline" size="sm" onClick={reloadAll}>
            <RefreshCw /> Refresh
          </Button>
        }
      />

      {view.error && !view.data ? (
        <p className="text-sm text-destructive">{view.error}</p>
      ) : !view.data ? (
        <Skeleton className="h-64 w-full" />
      ) : (
        <div className="grid gap-4">
          <PaymentsSwitch view={view.data} habitsFree={config.data?.features['habits']?.freeForAll === true} habitsOn={config.data?.features['habits']?.enabled !== false} onChanged={reloadAll} />
          <PaystackCard paystack={view.data.paystack} />
          {/* remount when the saved plans change so the form starts from them */}
          <PlansEditor key={JSON.stringify(view.data.billing)} billing={view.data.billing} onSaved={reloadAll} />
          <PaymentsTable page={payments.data} loading={payments.loading} />
        </div>
      )}
    </>
  )
}

// ── payments on / off ─────────────────────────────────────────────────────────

function PaymentsSwitch({
  view,
  habitsFree,
  habitsOn,
  onChanged,
}: {
  view: BillingView
  habitsFree: boolean
  habitsOn: boolean
  onChanged: () => void
}) {
  const [busy, setBusy] = useState(false)
  const [askOff, setAskOff] = useState(false)
  const enabled = view.billing.enabled

  async function setEnabled(on: boolean, makeHabitsFree = false) {
    setBusy(true)
    try {
      await api('billing', { method: 'PUT', body: { enabled: on } })
      if (makeHabitsFree) {
        await api('config/features/habits', { method: 'PUT', body: { freeForAll: true } })
      }
      toast.success(
        on
          ? 'Payments are ON — users can now see plans and pay in the app.'
          : makeHabitsFree
            ? 'Payments are OFF and the Habit Tracker is now free for everyone.'
            : 'Payments are OFF — the payment sections are hidden in the app.',
      )
      onChanged()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not save.')
    } finally {
      setBusy(false)
      setAskOff(false)
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Show payments in the app</CardTitle>
        <CardDescription>The master switch for everything to do with paying.</CardDescription>
      </CardHeader>
      <CardContent className="grid gap-4">
        <div className="flex items-center justify-between gap-4">
          <div>
            <Label htmlFor="billing-on" className="text-base">
              Payments are {enabled ? 'ON' : 'OFF'}
            </Label>
            <p className="mt-1 text-sm text-muted-foreground">
              {enabled ? 'Users can see your plans and pay with Paystack.' : 'No payment or Premium screens are shown anywhere in the app.'}
            </p>
          </div>
          <Switch
            id="billing-on"
            checked={enabled}
            disabled={busy}
            onCheckedChange={(on) => {
              if (on) void setEnabled(true)
              else if (habitsOn && !habitsFree) setAskOff(true)
              else void setEnabled(false)
            }}
          />
        </div>

        {enabled && habitsFree && (
          <Callout tone="info" title="The Habit Tracker is free for everyone right now">
            Even with payments on, nobody needs Premium for the Habit Tracker. To make it a Premium feature again, open <Link className="underline" href="/features">Features</Link> and switch off &ldquo;Free for everyone&rdquo;.
          </Callout>
        )}

        <Explain>
          <p>
            <strong>ON:</strong> the app shows a Premium section in the Profile with your plans (prices in ₦). Users pay on Paystack&rsquo;s secure page and Premium switches on automatically.
          </p>
          <p>
            <strong>OFF:</strong> the Premium / payment section disappears from the Profile and from the &ldquo;upgrade&rdquo; prompts. People who already paid keep Premium until their paid period ends. Nothing is deleted &mdash; you can switch it back on any time.
          </p>
          <p>
            To turn payments ON you need a connected Paystack account (below) and at least one <em>active</em> plan.
          </p>
        </Explain>
      </CardContent>

      <Dialog open={askOff} onOpenChange={(o) => !o && !busy && setAskOff(false)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Turn payments off?</DialogTitle>
            <DialogDescription>
              Users will stop seeing payment and Premium screens, and nobody will be able to pay.
            </DialogDescription>
          </DialogHeader>
          <Callout tone="warning" title="What about the Habit Tracker?">
            The Habit Tracker is currently a <strong>Premium feature</strong> (free trial, then Premium). If nobody can buy Premium, people whose trial ends would be locked out for good. Do you want to make it <strong>free for everyone</strong> instead?
          </Callout>
          <DialogFooter className="sm:flex-col sm:items-stretch">
            <Button disabled={busy} onClick={() => void setEnabled(false, true)}>
              {busy && <Loader2 className="animate-spin" />} Turn off &amp; make Habit Tracker free for everyone
            </Button>
            <Button variant="outline" disabled={busy} onClick={() => void setEnabled(false, false)}>
              Turn off, keep the Habit Tracker as it is
            </Button>
            <Button variant="ghost" disabled={busy} onClick={() => setAskOff(false)}>
              Cancel
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  )
}

// ── Paystack connection ───────────────────────────────────────────────────────

function CopyField({ label, value }: { label: string; value: string }) {
  const [done, setDone] = useState(false)
  return (
    <div className="grid gap-1.5">
      <Label className="text-xs text-muted-foreground">{label}</Label>
      <div className="flex gap-2">
        <Input readOnly value={value} className="font-mono text-xs" onFocus={(e) => e.currentTarget.select()} />
        <Button
          type="button"
          variant="outline"
          size="icon"
          aria-label={`Copy ${label}`}
          onClick={() => {
            void navigator.clipboard.writeText(value).then(() => {
              setDone(true)
              setTimeout(() => setDone(false), 1500)
            })
          }}
        >
          {done ? <Check /> : <Copy />}
        </Button>
      </div>
    </div>
  )
}

function PaystackCard({ paystack }: { paystack: BillingView['paystack'] }) {
  return (
    <Card>
      <CardHeader className="flex-row items-start justify-between gap-4">
        <div className="grid gap-1.5">
          <CardTitle className="flex items-center gap-2">
            <CreditCard className="size-5" /> Paystack
          </CardTitle>
          <CardDescription>Secure card, bank transfer and USSD payments in naira.</CardDescription>
        </div>
        {paystack.configured ? (
          paystack.mode === 'live' ? (
            <Badge variant="success">Connected · LIVE (real money)</Badge>
          ) : (
            <Badge variant="warning">Connected · TEST mode (no real money)</Badge>
          )
        ) : (
          <Badge variant="danger">Not connected</Badge>
        )}
      </CardHeader>
      <CardContent className="grid gap-4">
        {!paystack.configured && (
          <Callout tone="warning" title="Paystack is not connected yet">
            The server has no valid <code>PAYSTACK_SECRET_KEY</code>. Follow the steps below, then come back and refresh this page.
          </Callout>
        )}
        {paystack.configured && paystack.mode === 'test' && (
          <Callout tone="tip" title="You are in test mode">
            Payments here use Paystack&rsquo;s test cards and move no real money &mdash; perfect for trying everything. When you are ready, replace the key with your live key (<code>sk_live_…</code>) on the server.
          </Callout>
        )}
        <div className="grid gap-3 sm:grid-cols-2">
          <CopyField label="Webhook URL (paste into Paystack)" value={paystack.webhookUrl} />
          <CopyField label="Return page (set automatically)" value={paystack.callbackUrl} />
        </div>
        <Explain title="How to connect Paystack (step by step)">
          <ol className="list-decimal space-y-1 pl-5">
            <li>Create / open your account at <strong>dashboard.paystack.com</strong>.</li>
            <li>Go to <strong>Settings → API Keys &amp; Webhooks</strong>. Copy the <strong>Secret key</strong> (starts with <code>sk_test_</code> for test mode, <code>sk_live_</code> for live).</li>
            <li>On the same page paste the <strong>Webhook URL</strong> shown above into &ldquo;Test Webhook URL&rdquo; (and &ldquo;Live Webhook URL&rdquo; later). Save.</li>
            <li>On Render open your API service → <strong>Environment</strong> and add <code>PAYSTACK_SECRET_KEY</code> = your secret key. Also check <code>APP_URL</code> is your API address (https://readin-ehzw.onrender.com). Render restarts by itself.</li>
            <li>Come back here, press <strong>Refresh</strong>: the badge turns green/amber. Then add a plan below and switch payments on.</li>
          </ol>
          <p>The secret key is never shown in this panel and never goes into the app &mdash; it only lives in Render&rsquo;s settings.</p>
        </Explain>
      </CardContent>
    </Card>
  )
}

// ── plans editor ──────────────────────────────────────────────────────────────

interface Draft {
  id: string | undefined
  name: string
  description: string
  price: string
  days: string
  active: boolean
  badge: string
}

const toDraft = (p: BillingConfig['plans'][number]): Draft => ({
  id: p.id,
  name: p.name,
  description: p.description,
  price: String(p.priceKobo / 100),
  days: String(p.durationDays),
  active: p.active,
  badge: p.badge,
})

function PlansEditor({ billing, onSaved }: { billing: BillingConfig; onSaved: () => void }) {
  const [plans, setPlans] = useState<Draft[]>(() => billing.plans.map(toDraft))
  const [limit, setLimit] = useState(String(billing.freeLibraryLimit))
  const [saving, setSaving] = useState(false)

  const update = (i: number, patch: Partial<Draft>) =>
    setPlans((list) => list.map((p, n) => (n === i ? { ...p, ...patch } : p)))

  const add = (name: string, price: string, days: string) =>
    setPlans((list) => [...list, { id: undefined, name, description: '', price, days, active: true, badge: '' }])

  const errors: string[] = []
  const payload = plans.map((p, i) => {
    const kobo = nairaToKobo(p.price)
    const days = Number(p.days)
    if (!p.name.trim()) errors.push(`Plan ${i + 1}: enter a name.`)
    if (kobo === null || kobo < 5000) errors.push(`${p.name || `Plan ${i + 1}`}: the price must be at least ₦50.`)
    if (kobo !== null && kobo > 500_000_000) errors.push(`${p.name || `Plan ${i + 1}`}: the price is too high (max ₦5,000,000).`)
    if (!Number.isInteger(days) || days < 1 || days > 3650) errors.push(`${p.name || `Plan ${i + 1}`}: days must be a whole number from 1 to 3650.`)
    return {
      ...(p.id ? { id: p.id } : {}),
      name: p.name.trim(),
      description: p.description.trim(),
      priceKobo: kobo ?? 0,
      durationDays: days,
      active: p.active,
      badge: p.badge.trim(),
    }
  })
  const limitNum = Number(limit)
  if (!Number.isInteger(limitNum) || limitNum < 1 || limitNum > 1000) errors.push('Free book limit must be a whole number from 1 to 1000.')

  const changed = JSON.stringify(payload) !== JSON.stringify(billing.plans.map((p) => ({
    id: p.id,
    name: p.name,
    description: p.description,
    priceKobo: p.priceKobo,
    durationDays: p.durationDays,
    active: p.active,
    badge: p.badge,
  }))) || limitNum !== billing.freeLibraryLimit

  async function save() {
    setSaving(true)
    try {
      await api('billing', { method: 'PUT', body: { plans: payload, freeLibraryLimit: limitNum } })
      toast.success('Plans saved.')
      onSaved()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not save.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Plans & prices</CardTitle>
        <CardDescription>Everything is in Nigerian naira (₦). Users pay once per plan and get Premium for the number of days you set.</CardDescription>
      </CardHeader>
      <CardContent className="grid gap-4">
        <Explain>
          <p><strong>Price (₦):</strong> what the user pays, e.g. <code>1500</code> = ₦1,500. Minimum ₦50. You can change it any time &mdash; only <em>new</em> payments use the new price.</p>
          <p><strong>Premium lasts (days):</strong> 30 = about a month, 365 = a year. If someone pays again before their Premium ends, the new days are added <em>after</em> what they have left, so nothing is lost.</p>
          <p><strong>Active:</strong> ON = shown in the app. OFF = hidden (kept for your records). At least one active plan is needed to turn payments on.</p>
          <p><strong>Badge:</strong> a small label on the plan card, e.g. &ldquo;Best value&rdquo;.</p>
          <p>This is a one-time payment per period (like buying a month), not an automatic subscription &mdash; users are never charged again without choosing to.</p>
        </Explain>

        {plans.length === 0 && (
          <p className="rounded-lg border border-dashed p-6 text-center text-sm text-muted-foreground">
            No plans yet. Add one to get started.
          </p>
        )}

        {plans.map((p, i) => (
          <div key={p.id ?? `new-${i}`} className="grid gap-3 rounded-lg border p-4">
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <Switch checked={p.active} onCheckedChange={(v) => update(i, { active: v })} aria-label="Plan active" />
                <span className="text-sm text-muted-foreground">{p.active ? 'Active (visible in the app)' : 'Hidden'}</span>
              </div>
              <Button variant="ghost" size="icon" aria-label="Remove plan" onClick={() => setPlans((l) => l.filter((_, n) => n !== i))}>
                <Trash2 className="text-destructive" />
              </Button>
            </div>
            <div className="grid gap-3 sm:grid-cols-4">
              <div className="grid gap-1.5 sm:col-span-2">
                <Label>Plan name</Label>
                <Input value={p.name} maxLength={40} onChange={(e) => update(i, { name: e.target.value })} placeholder="Monthly" />
              </div>
              <div className="grid gap-1.5">
                <Label>Price (₦)</Label>
                <Input inputMode="decimal" value={p.price} onChange={(e) => update(i, { price: e.target.value })} placeholder="1500" />
              </div>
              <div className="grid gap-1.5">
                <Label>Premium lasts (days)</Label>
                <Input inputMode="numeric" value={p.days} onChange={(e) => update(i, { days: e.target.value })} placeholder="30" />
              </div>
              <div className="grid gap-1.5 sm:col-span-3">
                <Label>Short description (optional)</Label>
                <Input value={p.description} maxLength={120} onChange={(e) => update(i, { description: e.target.value })} placeholder="All Premium features for 30 days" />
              </div>
              <div className="grid gap-1.5">
                <Label>Badge (optional)</Label>
                <Input value={p.badge} maxLength={20} onChange={(e) => update(i, { badge: e.target.value })} placeholder="Best value" />
              </div>
            </div>
            <p className="text-xs text-muted-foreground">
              Users will see: <strong>{p.name || 'Plan'}</strong> &mdash; {nairaToKobo(p.price) ? formatNaira(nairaToKobo(p.price) as number) : '₦—'} for {p.days || '—'} days
            </p>
          </div>
        ))}

        <div className="flex flex-wrap gap-2">
          <Button variant="outline" size="sm" disabled={plans.length >= 6} onClick={() => add('Monthly', '1500', '30')}>
            <Plus /> Add Monthly (30 days)
          </Button>
          <Button variant="outline" size="sm" disabled={plans.length >= 6} onClick={() => add('Yearly', '15000', '365')}>
            <Plus /> Add Yearly (365 days)
          </Button>
          <Button variant="outline" size="sm" disabled={plans.length >= 6} onClick={() => add('', '', '30')}>
            <Plus /> Add custom plan
          </Button>
        </div>
        <p className="text-xs text-muted-foreground">The example prices are only suggestions &mdash; type your own.</p>

        <div className="grid gap-2 border-t pt-4">
          <div className="flex items-center justify-between gap-4">
            <div>
              <Label htmlFor="free-limit">Books a Free user can keep</Label>
              <p className="text-xs text-muted-foreground">Premium users have no limit.</p>
            </div>
            <Input id="free-limit" inputMode="numeric" className="w-24" value={limit} onChange={(e) => setLimit(e.target.value)} />
          </div>
          <Explain>
            <p>When a Free user reaches this number of books, adding another shows &ldquo;library full&rdquo; (and, if payments are on, a prompt to upgrade). Raising the number helps everyone immediately; lowering it never deletes books &mdash; users above the limit just can&rsquo;t add more.</p>
          </Explain>
        </div>

        {errors.length > 0 && (
          <Callout tone="warning" title="Fix these before saving">
            <ul className="list-disc pl-5">
              {errors.map((er) => (
                <li key={er}>{er}</li>
              ))}
            </ul>
          </Callout>
        )}
      </CardContent>
      <CardFooter className="justify-end gap-2">
        {changed && <span className="text-xs text-muted-foreground">You have unsaved changes</span>}
        <Button onClick={save} disabled={!changed || errors.length > 0 || saving}>
          {saving ? <Loader2 className="animate-spin" /> : <Save />} Save plans
        </Button>
      </CardFooter>
    </Card>
  )
}

// ── recent payments ───────────────────────────────────────────────────────────

const STATUS: Record<PaymentRow['status'], { label: string; variant: 'success' | 'warning' | 'danger' | 'secondary' }> = {
  success: { label: 'Paid', variant: 'success' },
  pending: { label: 'Waiting', variant: 'warning' },
  failed: { label: 'Failed', variant: 'danger' },
  abandoned: { label: 'Abandoned', variant: 'secondary' },
}

function PaymentsTable({ page, loading }: { page: PaymentsPage | undefined; loading: boolean }) {
  return (
    <Card className="py-4">
      <CardHeader>
        <CardTitle>Recent payments</CardTitle>
        <CardDescription>The latest 15 attempts. &ldquo;Waiting&rdquo; = the user started paying but has not finished; &ldquo;Abandoned&rdquo; = they closed the Paystack page.</CardDescription>
      </CardHeader>
      <CardContent className="px-2">
        {!page && loading ? (
          <Skeleton className="m-4 h-32" />
        ) : !page || page.items.length === 0 ? (
          <p className="p-6 text-center text-sm text-muted-foreground">No payments yet.</p>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Date</TableHead>
                <TableHead>User</TableHead>
                <TableHead>Plan</TableHead>
                <TableHead>Amount</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Premium until</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {page.items.map((p) => (
                <TableRow key={p.id}>
                  <TableCell className="text-muted-foreground">{formatDateTime(p.paidAt ?? p.createdAt)}</TableCell>
                  <TableCell>
                    <Link href={`/users/${p.userId}`} className="hover:underline">
                      {p.email}
                    </Link>
                  </TableCell>
                  <TableCell>{p.planName}</TableCell>
                  <TableCell className="font-medium">{p.amountText}</TableCell>
                  <TableCell>
                    <Badge variant={STATUS[p.status].variant}>{STATUS[p.status].label}</Badge>
                  </TableCell>
                  <TableCell className="text-muted-foreground">{formatDateTime(p.premiumUntil)}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </CardContent>
    </Card>
  )
}
