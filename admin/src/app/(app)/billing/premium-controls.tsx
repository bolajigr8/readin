'use client'

// S9.2 — Premium controls on the Billing page: wording/hooks, free trial, reminder schedule.
// Every card saves only its own part (PUT /admin/billing with one key), so cards never overwrite each other.

import { useState } from 'react'
import { BellRing, Gift, Loader2, Megaphone, Plus, Save, Send, Trash2 } from 'lucide-react'
import { toast } from 'sonner'
import { Callout, Explain } from '@/components/help'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { NativeSelect } from '@/components/ui/native-select'
import { Switch } from '@/components/ui/switch'
import { api } from '@/lib/api'
import type { BillingConfig, ReminderStep } from '@/lib/types'

async function saveBilling(body: Record<string, unknown>, ok: string, onSaved: () => void): Promise<void> {
  try {
    await api('billing', { method: 'PUT', body })
    toast.success(ok)
    onSaved()
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Could not save.')
  }
}

// ── wording / hooks ───────────────────────────────────────────────────────────

export function PremiumWording({ billing, onSaved }: { billing: BillingConfig; onSaved: () => void }) {
  const m = billing.marketing
  const [headline, setHeadline] = useState(m.headline)
  const [perDay, setPerDay] = useState(m.showPerDay)
  const [savings, setSavings] = useState(m.showSavings)
  const [saving, setSaving] = useState(false)
  const changed = headline.trim() !== m.headline || perDay !== m.showPerDay || savings !== m.showSavings

  async function save() {
    setSaving(true)
    await saveBilling(
      { marketing: { headline: headline.trim(), showPerDay: perDay, showSavings: savings } },
      'Premium screen wording saved.',
      onSaved,
    )
    setSaving(false)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Megaphone className="size-5" /> Premium screen wording
        </CardTitle>
        <CardDescription>The headline and the little &ldquo;hooks&rdquo; that show people how good the price is.</CardDescription>
      </CardHeader>
      <CardContent className="grid gap-4">
        <div className="grid gap-1.5">
          <Label htmlFor="headline">Headline (optional)</Label>
          <Input
            id="headline"
            value={headline}
            maxLength={80}
            onChange={(e) => setHeadline(e.target.value)}
            placeholder="Read without limits for less than ₦24 a day"
          />
          <p className="text-xs text-muted-foreground">
            Empty = the app&rsquo;s standard text. {headline.length}/80 characters.
          </p>
        </div>
        <div className="flex items-center justify-between gap-4">
          <div>
            <Label htmlFor="per-day">Show the price per day</Label>
            <p className="text-xs text-muted-foreground">e.g. ₦700 for 30 days &rarr; &ldquo;less than ₦24 a day&rdquo;.</p>
          </div>
          <Switch id="per-day" checked={perDay} onCheckedChange={setPerDay} />
        </div>
        <div className="flex items-center justify-between gap-4">
          <div>
            <Label htmlFor="savings">Show savings on longer plans</Label>
            <p className="text-xs text-muted-foreground">
              e.g. ₦7,000 a year vs ₦700 a month &rarr; &ldquo;2 months free &middot; save ₦1,400&rdquo;.
            </p>
          </div>
          <Switch id="savings" checked={savings} onCheckedChange={setSavings} />
        </div>
        <Explain>
          <p>
            The price per day and the savings are <strong>calculated automatically</strong> from your plans, so they are always
            right when you change a price. You can see them under each plan in &ldquo;Plans &amp; prices&rdquo; above (after saving).
          </p>
        </Explain>
      </CardContent>
      <CardFooter className="justify-end">
        <Button onClick={save} disabled={!changed || saving}>
          {saving ? <Loader2 className="animate-spin" /> : <Save />} Save wording
        </Button>
      </CardFooter>
    </Card>
  )
}

// ── free trial ────────────────────────────────────────────────────────────────

export function FreeTrialCard({ billing, onSaved }: { billing: BillingConfig; onSaved: () => void }) {
  const [on, setOn] = useState(billing.trialDays > 0)
  const [days, setDays] = useState(String(billing.trialDays > 0 ? billing.trialDays : 7))
  const [saving, setSaving] = useState(false)
  const n = Number(days)
  const valid = !on || (Number.isInteger(n) && n >= 1 && n <= 90)
  const next = on ? n : 0
  const changed = next !== billing.trialDays

  async function save() {
    setSaving(true)
    await saveBilling(
      { trialDays: next },
      next > 0 ? `Free trial is ON: ${next} days for new members.` : 'Free trial is OFF.',
      onSaved,
    )
    setSaving(false)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Gift className="size-5" /> Free Premium trial
        </CardTitle>
        <CardDescription>Let new people try Premium for free before they pay.</CardDescription>
      </CardHeader>
      <CardContent className="grid gap-4">
        <div className="flex items-center justify-between gap-4">
          <div>
            <Label htmlFor="trial-on" className="text-base">
              Free trial is {on ? 'ON' : 'OFF'}
            </Label>
            <p className="mt-1 text-sm text-muted-foreground">
              {on ? 'The Premium screen shows a “Start free trial” button.' : 'No trial button is shown.'}
            </p>
          </div>
          <Switch id="trial-on" checked={on} onCheckedChange={setOn} />
        </div>
        {on && (
          <div className="grid max-w-xs gap-1.5">
            <Label htmlFor="trial-days">Trial length (days)</Label>
            <Input id="trial-days" inputMode="numeric" value={days} onChange={(e) => setDays(e.target.value)} />
            {!valid && <p className="text-xs text-destructive">Enter a whole number from 1 to 90.</p>}
          </div>
        )}
        <Explain>
          <p>
            Each account can use the trial <strong>once</strong>. People who have already paid for Premium don&rsquo;t get it, and
            nobody is charged when it ends &mdash; Premium simply stops, and the reminders below invite them to buy.
          </p>
          <p>
            <strong>Google Play version:</strong> trials for Play subscriptions are set in the Play Console (Google requires it).
            This switch controls the trial in the app&rsquo;s own Premium screen.
          </p>
        </Explain>
      </CardContent>
      <CardFooter className="justify-end">
        <Button onClick={save} disabled={!changed || !valid || saving}>
          {saving ? <Loader2 className="animate-spin" /> : <Save />} Save trial
        </Button>
      </CardFooter>
    </Card>
  )
}

// ── reminders ─────────────────────────────────────────────────────────────────

type When = 'before' | 'on' | 'after'
interface StepDraft {
  when: When
  days: string
  inApp: boolean
  email: boolean
}

const RECOMMENDED: ReminderStep[] = [
  { offsetDays: -5, inApp: true, email: true },
  { offsetDays: -2, inApp: true, email: true },
  { offsetDays: 0, inApp: true, email: true },
  { offsetDays: 3, inApp: true, email: true },
]

const toDraft = (s: ReminderStep): StepDraft => ({
  when: s.offsetDays < 0 ? 'before' : s.offsetDays === 0 ? 'on' : 'after',
  days: String(Math.abs(s.offsetDays) || 1),
  inApp: s.inApp,
  email: s.email,
})

const offsetOf = (d: StepDraft): number => (d.when === 'on' ? 0 : (d.when === 'before' ? -1 : 1) * Number(d.days))

const describe = (offset: number): string => {
  const n = Math.abs(offset)
  const days = `${n} day${n === 1 ? '' : 's'}`
  if (offset < 0) return `“Your Premium ends in ${days}”`
  if (offset === 0) return '“Your Premium ends today”'
  return '“We miss you on ReadIn Premium” (renew invitation)'
}

export function RemindersCard({ billing, onSaved }: { billing: BillingConfig; onSaved: () => void }) {
  const [enabled, setEnabled] = useState(billing.reminders.enabled)
  const [steps, setSteps] = useState<StepDraft[]>(() => billing.reminders.steps.map(toDraft))
  const [saving, setSaving] = useState(false)
  const [running, setRunning] = useState(false)

  const update = (i: number, patch: Partial<StepDraft>) =>
    setSteps((list) => list.map((s, n) => (n === i ? { ...s, ...patch } : s)))

  const errors: string[] = []
  steps.forEach((s, i) => {
    const d = Number(s.days)
    if (s.when !== 'on' && (!Number.isInteger(d) || d < 1 || d > 30)) errors.push(`Reminder ${i + 1}: days must be 1 to 30.`)
  })
  const offsets = steps.map(offsetOf)
  if (new Set(offsets).size !== offsets.length) errors.push('Two reminders are on the same day — remove one.')

  const payload = steps
    .map((s) => ({ offsetDays: offsetOf(s), inApp: s.inApp, email: s.email }))
    .sort((a, b) => a.offsetDays - b.offsetDays)
  const changed =
    enabled !== billing.reminders.enabled || JSON.stringify(payload) !== JSON.stringify(billing.reminders.steps)

  async function save() {
    setSaving(true)
    await saveBilling({ reminders: { enabled, steps: payload } }, 'Reminder schedule saved.', onSaved)
    setSaving(false)
  }

  async function runNow() {
    setRunning(true)
    try {
      const r = await api<{ checked: number; sent: number }>('billing/reminders/run', { method: 'POST' })
      toast.success(r.sent === 0 ? 'No reminders were due right now.' : `Sent ${r.sent} reminder e-mail(s).`)
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not run the reminders.')
    } finally {
      setRunning(false)
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <BellRing className="size-5" /> Premium reminders
        </CardTitle>
        <CardDescription>Kind reminders before Premium ends, on the day, and an invitation to come back.</CardDescription>
      </CardHeader>
      <CardContent className="grid gap-4">
        <div className="flex items-center justify-between gap-4">
          <div>
            <Label htmlFor="rem-on" className="text-base">
              Reminders are {enabled ? 'ON' : 'OFF'}
            </Label>
            <p className="mt-1 text-sm text-muted-foreground">
              {enabled ? 'Users are reminded on the days below.' : 'No reminders are shown or sent.'}
            </p>
          </div>
          <Switch id="rem-on" checked={enabled} onCheckedChange={setEnabled} />
        </div>

        {enabled && (
          <>
            {steps.length === 0 && (
              <p className="rounded-lg border border-dashed p-6 text-center text-sm text-muted-foreground">
                No reminder days yet. Add one, or use the recommended schedule.
              </p>
            )}
            {steps.map((s, i) => (
              <div key={i} className="grid min-w-0 gap-3 rounded-lg border p-4">
                <div className="flex flex-wrap items-end gap-3">
                  {s.when !== 'on' && (
                    <div className="grid w-24 gap-1.5">
                      <Label>Days</Label>
                      <Input inputMode="numeric" value={s.days} onChange={(e) => update(i, { days: e.target.value })} />
                    </div>
                  )}
                  <div className="grid min-w-40 flex-1 gap-1.5">
                    <Label>When</Label>
                    <NativeSelect value={s.when} onChange={(e) => update(i, { when: e.target.value as When })}>
                      <option value="before">before Premium ends</option>
                      <option value="on">on the day it ends</option>
                      <option value="after">after it ended</option>
                    </NativeSelect>
                  </div>
                  <Button variant="ghost" size="icon" aria-label="Remove reminder" onClick={() => setSteps((l) => l.filter((_, n) => n !== i))}>
                    <Trash2 className="text-destructive" />
                  </Button>
                </div>
                <div className="flex flex-wrap gap-6">
                  <label className="flex items-center gap-2 text-sm">
                    <Switch checked={s.inApp} onCheckedChange={(v) => update(i, { inApp: v })} aria-label="Banner in the app" />
                    Banner in the app
                  </label>
                  <label className="flex items-center gap-2 text-sm">
                    <Switch checked={s.email} onCheckedChange={(v) => update(i, { email: v })} aria-label="E-mail" />
                    E-mail
                  </label>
                </div>
                <p className="text-xs text-muted-foreground">
                  {Number.isFinite(offsetOf(s)) ? describe(offsetOf(s)) : '—'}
                  {!s.inApp && !s.email && ' — both off: this reminder does nothing.'}
                </p>
              </div>
            ))}
            <div className="flex flex-wrap gap-2">
              <Button
                variant="outline"
                size="sm"
                disabled={steps.length >= 6}
                onClick={() => setSteps((l) => [...l, { when: 'before', days: '1', inApp: true, email: true }])}
              >
                <Plus /> Add a reminder day
              </Button>
              <Button variant="outline" size="sm" onClick={() => setSteps(RECOMMENDED.map(toDraft))}>
                Use recommended days
              </Button>
            </div>
          </>
        )}

        {errors.length > 0 && (
          <Callout tone="warning" title="Please fix">
            <ul className="list-disc pl-5">
              {errors.map((e) => (
                <li key={e}>{e}</li>
              ))}
            </ul>
          </Callout>
        )}

        <Explain>
          <p>
            <strong>Recommended days:</strong> 5 and 2 days before Premium ends, on the day it ends, and 3 days after.
          </p>
          <p>
            <strong>Banner in the app:</strong> a friendly message on the Home screen with a &ldquo;Renew&rdquo; button, shown from the
            first reminder day until a week after the last one.
          </p>
          <p>
            <strong>E-mail:</strong> sent once per reminder day (the server checks every hour). If several are due at the same time,
            only the latest is sent &mdash; nobody gets a pile of e-mails. Users can switch e-mails off in the app (Profile).
          </p>
          <p>Renewing early never loses time: the new days are added after what is left.</p>
        </Explain>
        <div className="flex flex-wrap items-center gap-3 border-t pt-4">
          <Button variant="outline" size="sm" onClick={runNow} disabled={running}>
            {running ? <Loader2 className="animate-spin" /> : <Send />} Send due reminders now
          </Button>
          <span className="text-xs text-muted-foreground">
            Normally automatic every hour. This only sends reminders that are due and not sent yet.
          </span>
        </div>
      </CardContent>
      <CardFooter className="justify-end">
        <Button onClick={save} disabled={!changed || errors.length > 0 || saving}>
          {saving ? <Loader2 className="animate-spin" /> : <Save />} Save reminders
        </Button>
      </CardFooter>
    </Card>
  )
}
