'use client'

import { useState } from 'react'
import { Loader2, Save } from 'lucide-react'
import { toast } from 'sonner'
import { Callout, Explain } from '@/components/help'
import { PageHeader } from '@/components/page-header'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Separator } from '@/components/ui/separator'
import { Skeleton } from '@/components/ui/skeleton'
import { Switch } from '@/components/ui/switch'
import { useApi } from '@/hooks/use-api'
import { api } from '@/lib/api'
import { FEATURE_LABELS, type AdminConfig, type FeatureConfig } from '@/lib/types'

export default function FeaturesPage() {
  const { data, error, reload } = useApi<AdminConfig>('config')

  return (
    <>
      <PageHeader
        title="Features"
        description="Decide who can use each feature of the app. Changes reach the app within about 30 seconds — no new release needed."
      />
      <div className="mb-4">
        <Explain title="How access is decided (read this once)">
          <p>For each user the app checks these rules <strong>in this order</strong> and stops at the first one that applies:</p>
          <ol className="list-decimal space-y-1 pl-5">
            <li><strong>Administrator?</strong> Admin accounts always have access (so you can test).</li>
            <li><strong>Feature enabled = OFF?</strong> Nobody else can use it.</li>
            <li><strong>Blocked on that user&rsquo;s page?</strong> Then that user cannot use it.</li>
            <li><strong>Free for everyone = ON?</strong> Everybody can use it free, with no trial.</li>
            <li><strong>Gift from you</strong> (&ldquo;Grant access&rdquo; on a user&rsquo;s page) still running? They can use it.</li>
            <li><strong>Premium plan</strong> and &ldquo;Included in Premium&rdquo; = ON? They can use it.</li>
            <li><strong>Free trial</strong>: starts the first time the user opens the feature, lasts the number of days below. After that the feature is locked until they get Premium or a gift.</li>
          </ol>
        </Explain>
      </div>
      {error && !data ? (
        <p className="text-sm text-destructive">{error}</p>
      ) : !data ? (
        <Skeleton className="h-64 w-full" />
      ) : (
        <div className="grid gap-4">
          {data.keys.map((key) => (
            // remount when the saved values change, so the form starts from them
            <FeatureCard key={`${key}:${JSON.stringify(data.features[key])}`} featureKey={key} config={data.features[key]} onSaved={reload} />
          ))}
        </div>
      )}
    </>
  )
}

function FeatureCard({
  featureKey,
  config,
  onSaved,
}: {
  featureKey: string
  config: FeatureConfig | undefined
  onSaved: () => void
}) {
  const label = FEATURE_LABELS[featureKey] ?? { name: featureKey, description: '' }
  const [enabled, setEnabled] = useState(config?.enabled ?? true)
  const [free, setFree] = useState(config?.freeForAll ?? false)
  const [trialDays, setTrialDays] = useState(String(config?.trialDays ?? 14))
  const [premium, setPremium] = useState(config?.includedInPremium ?? true)
  const [saving, setSaving] = useState(false)

  const days = Number(trialDays)
  const valid = Number.isInteger(days) && days >= 0 && days <= 365
  const changed =
    enabled !== (config?.enabled ?? true) ||
    free !== (config?.freeForAll ?? false) ||
    days !== (config?.trialDays ?? 14) ||
    premium !== (config?.includedInPremium ?? true)

  async function save() {
    setSaving(true)
    try {
      await api(`config/features/${featureKey}`, {
        method: 'PUT',
        body: { enabled, trialDays: days, includedInPremium: premium, freeForAll: free },
      })
      toast.success(`${label.name} saved.`)
      onSaved()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not save.')
    } finally {
      setSaving(false)
    }
  }

  const summary = !enabled
    ? 'Switched OFF for everyone except administrators.'
    : free
      ? 'FREE for every signed-in user — no trial and no Premium needed.'
      : days > 0
        ? `Each user gets a ${days}-day free trial${premium ? ', then needs Premium' : ' (Premium does not unlock it)'}.`
        : premium
          ? 'No trial — only Premium users (and users you gift access to) can use it.'
          : 'Locked — only users you gift access to can use it.'

  return (
    <Card>
      <CardHeader>
        <CardTitle>{label.name}</CardTitle>
        <CardDescription>{label.description}</CardDescription>
      </CardHeader>
      <CardContent className="grid gap-5">
        <Callout tone="info" title="Right now">
          {summary}
        </Callout>

        <div className="grid gap-2">
          <div className="flex items-center justify-between gap-4">
            <div>
              <Label htmlFor={`${featureKey}-enabled`}>Feature enabled</Label>
              <p className="text-xs text-muted-foreground">The on/off switch for the whole feature.</p>
            </div>
            <Switch id={`${featureKey}-enabled`} checked={enabled} onCheckedChange={setEnabled} />
          </div>
          <Explain>
            <p><strong>ON (normal):</strong> the feature works according to the rules below.</p>
            <p><strong>OFF:</strong> the feature is switched off for <em>everyone</em>. In the app people see &ldquo;this feature is switched off&rdquo;; their reminders stop and their data is kept safely.</p>
            <p><strong>&ldquo;Administrators excepted&rdquo;</strong> means: accounts that have the <em>Admin</em> role (like yours) can still open the feature even while it is off, so you can test or fix it while it is hidden from everybody else. Normal users cannot.</p>
          </Explain>
        </div>

        <Separator />

        <div className="grid gap-2">
          <div className="flex items-center justify-between gap-4">
            <div>
              <Label htmlFor={`${featureKey}-free`}>Free for everyone</Label>
              <p className="text-xs text-muted-foreground">Everyone can use it, no trial, no payment.</p>
            </div>
            <Switch id={`${featureKey}-free`} checked={free} onCheckedChange={setFree} disabled={!enabled} />
          </div>
          <Explain>
            <p><strong>ON:</strong> every signed-in user gets this feature for free, permanently &mdash; even users whose trial already ended. The trial and Premium settings below are ignored while this is on.</p>
            <p><strong>OFF:</strong> the normal rules apply (trial, then Premium).</p>
            <p>Use it when you do not want to charge for a feature &mdash; for example when you switch payments off. A block you put on a specific user still wins.</p>
          </Explain>
        </div>

        <Separator />

        <div className={free ? 'grid gap-5 opacity-50' : 'grid gap-5'}>
          <div className="grid gap-2">
            <div className="flex items-center justify-between gap-4">
              <div>
                <Label htmlFor={`${featureKey}-days`}>Free trial (days)</Label>
                <p className="text-xs text-muted-foreground">How long a new user can try it for free.</p>
              </div>
              <Input
                id={`${featureKey}-days`}
                type="number"
                min={0}
                max={365}
                className="w-24"
                value={trialDays}
                onChange={(e) => setTrialDays(e.target.value)}
                aria-invalid={!valid}
                disabled={free}
              />
            </div>
            <Explain>
              <p>The trial starts the <strong>first time the user opens the feature</strong> (not when they sign up), and the clock is kept on the server &mdash; users cannot restart it.</p>
              <p><strong>14</strong> = two weeks. <strong>0</strong> = no trial at all (only Premium users or gifted users get in). Maximum 365.</p>
              <p>Changing the number also changes trials already running. Example: a user on day 10 of a 14-day trial has 4 days left; if you change it to 30 they now have 20 days left. To give one single person more time use <em>Users → Grant access</em> instead.</p>
            </Explain>
          </div>

          <div className="grid gap-2">
            <div className="flex items-center justify-between gap-4">
              <div>
                <Label htmlFor={`${featureKey}-premium`}>Included in Premium</Label>
                <p className="text-xs text-muted-foreground">Premium subscribers skip the trial.</p>
              </div>
              <Switch id={`${featureKey}-premium`} checked={premium} onCheckedChange={setPremium} disabled={free} />
            </div>
            <Explain>
              <p><strong>ON:</strong> anyone with an active Premium plan can use the feature straight away.</p>
              <p><strong>OFF:</strong> paying for Premium does <em>not</em> unlock this feature; only the trial or a gift from you does. Use it if you plan to sell this feature separately later.</p>
            </Explain>
          </div>
        </div>
      </CardContent>
      <CardFooter className="justify-end gap-2">
        {changed && <span className="text-xs text-muted-foreground">You have unsaved changes</span>}
        <Button onClick={save} disabled={!valid || !changed || saving}>
          {saving ? <Loader2 className="animate-spin" /> : <Save />} Save changes
        </Button>
      </CardFooter>
    </Card>
  )
}
