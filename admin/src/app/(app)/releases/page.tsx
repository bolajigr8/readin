'use client'

// S2 — App versions: tell phones that a new version exists (optional banner or a required update).

import { useState } from 'react'
import { Loader2, Plus, RefreshCw, Save } from 'lucide-react'
import { toast } from 'sonner'
import { Callout, Explain } from '@/components/help'
import { PageHeader } from '@/components/page-header'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { NativeSelect } from '@/components/ui/native-select'
import { Skeleton } from '@/components/ui/skeleton'
import { Switch } from '@/components/ui/switch'
import { useApi } from '@/hooks/use-api'
import { api } from '@/lib/api'
import type { AppReleaseRow } from '@/lib/types'
import { formatDateTime } from '@/lib/utils'

const PLAY_URL = 'https://play.google.com/store/apps/details?id=com.micbol.readin'
const channelName = (c: AppReleaseRow['channel']) => (c === 'play' ? 'Google Play version' : 'Website (APK) version')
const mb = (bytes: number) => (bytes > 0 ? `${(bytes / 1048576).toFixed(1)} MB` : '—')

export default function ReleasesPage() {
  const list = useApi<{ items: AppReleaseRow[] }>('releases')
  const items = list.data?.items ?? []
  return (
    <>
      <PageHeader
        title="App versions"
        description="Tell people's phones when a new ReadIn version is ready — as a friendly reminder, or as a required update."
        actions={
          <Button variant="outline" size="sm" onClick={list.reload}>
            <RefreshCw /> Refresh
          </Button>
        }
      />
      <div className="grid gap-4 [&>*]:min-w-0">
        <NewRelease existing={items} onSaved={list.reload} />
        {list.error && !list.data ? (
          <p className="text-sm text-destructive">{list.error}</p>
        ) : !list.data ? (
          <Skeleton className="h-40 w-full" />
        ) : items.length === 0 ? (
          <p className="rounded-lg border border-dashed p-6 text-center text-sm text-muted-foreground">
            No versions yet. Add the version you just released above.
          </p>
        ) : (
          (['direct', 'play'] as const).map((ch) =>
            items.some((r) => r.channel === ch) ? (
              <Card key={ch}>
                <CardHeader>
                  <CardTitle>{channelName(ch)}</CardTitle>
                  <CardDescription>Newest first. Phones are offered the newest PUBLISHED version.</CardDescription>
                </CardHeader>
                <CardContent className="grid gap-3">
                  {items
                    .filter((r) => r.channel === ch)
                    .map((r) => (
                      <ReleaseRow key={r.id} r={r} onSaved={list.reload} />
                    ))}
                </CardContent>
              </Card>
            ) : null,
          )
        )}
      </div>
    </>
  )
}

// ── one release ───────────────────────────────────────────────────────────────

function ReleaseRow({ r, onSaved }: { r: AppReleaseRow; onSaved: () => void }) {
  const [busy, setBusy] = useState(false)
  const [askMandatory, setAskMandatory] = useState(false)
  const [minCode, setMinCode] = useState(String(r.minSupportedVersionCode))

  async function patch(body: Record<string, unknown>, ok: string) {
    setBusy(true)
    try {
      await api(`releases/${r.id}`, { method: 'PATCH', body })
      toast.success(ok)
      onSaved()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not save.')
    } finally {
      setBusy(false)
      setAskMandatory(false)
    }
  }

  const minNum = Number(minCode)
  const minValid = Number.isInteger(minNum) && minNum >= 0 && minNum <= r.versionCode

  return (
    <div className="grid gap-3 rounded-lg border p-4">
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-lg font-semibold">{r.version}</span>
        <span className="text-sm text-muted-foreground">(version code {r.versionCode})</span>
        {r.published ? <Badge variant="success">Published</Badge> : <Badge variant="warning">Draft — phones don&rsquo;t see it</Badge>}
        {r.mandatory && <Badge variant="danger">Required update</Badge>}
      </div>
      <p className="break-all text-xs text-muted-foreground">
        {mb(r.sizeBytes)} · {r.releasedAt ? `released ${formatDateTime(r.releasedAt)}` : 'not released yet'} · {r.downloadUrl}
      </p>
      {r.notes.length > 0 && (
        <ul className="list-disc pl-5 text-sm">
          {r.notes.map((n) => (
            <li key={n}>{n}</li>
          ))}
        </ul>
      )}
      <div className="flex flex-wrap items-center gap-x-6 gap-y-3">
        <label className="flex items-center gap-2 text-sm">
          <Switch
            checked={r.published}
            disabled={busy}
            onCheckedChange={(v) => void patch({ published: v }, v ? 'Published — phones will see it within a minute.' : 'Unpublished.')}
            aria-label="Published"
          />
          Published
        </label>
        <label className="flex items-center gap-2 text-sm">
          <Switch
            checked={r.mandatory}
            disabled={busy}
            onCheckedChange={(v) => (v ? setAskMandatory(true) : void patch({ mandatory: false }, 'No longer a required update.'))}
            aria-label="Required update"
          />
          Required update
        </label>
        <div className="flex items-end gap-2">
          <div className="grid gap-1">
            <Label className="text-xs">Oldest version code still allowed</Label>
            <Input className="h-8 w-24" inputMode="numeric" value={minCode} onChange={(e) => setMinCode(e.target.value)} />
          </div>
          <Button
            size="sm"
            variant="outline"
            disabled={busy || !minValid || minNum === r.minSupportedVersionCode}
            onClick={() => void patch({ minSupportedVersionCode: minNum }, 'Saved.')}
          >
            <Save /> Save
          </Button>
        </div>
      </div>
      {!minValid && <p className="text-xs text-destructive">Enter a whole number from 0 to {r.versionCode}.</p>}

      <Dialog open={askMandatory} onOpenChange={setAskMandatory}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Make {r.version} a required update?</DialogTitle>
            <DialogDescription>
              Everyone with an older version will see a full screen that asks them to update before they can keep using
              ReadIn. Use this only for important fixes (security, a serious bug, a change older versions can&rsquo;t handle).
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAskMandatory(false)}>
              Cancel
            </Button>
            <Button variant="destructive" disabled={busy} onClick={() => void patch({ mandatory: true }, `${r.version} is now a required update.`)}>
              Yes, require it
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}

// ── add a release ─────────────────────────────────────────────────────────────

function NewRelease({ existing, onSaved }: { existing: AppReleaseRow[]; onSaved: () => void }) {
  const [channel, setChannel] = useState<AppReleaseRow['channel']>('direct')
  const [version, setVersion] = useState('')
  const [code, setCode] = useState('')
  const [url, setUrl] = useState('')
  const [sha, setSha] = useState('')
  const [sizeMb, setSizeMb] = useState('')
  const [notes, setNotes] = useState('')
  const [publish, setPublish] = useState(true)
  const [saving, setSaving] = useState(false)

  const codeNum = Number(code)
  const errors: string[] = []
  if (version && !/^\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(version.trim())) errors.push('Version looks like 1.0.2 (three numbers).')
  if (code && (!Number.isInteger(codeNum) || codeNum < 1)) errors.push('Version code is a whole number, e.g. 3.')
  if (code && existing.some((r) => r.channel === channel && r.versionCode === codeNum)) errors.push('This version code already exists.')
  if (url && !/^https:\/\//.test(url.trim())) errors.push('The download link must start with https://')
  if (sha && !/^[a-f0-9]{64}$/i.test(sha.trim())) errors.push('The SHA-256 is 64 letters/numbers (from the release notes file).')
  const ready = version && code && url && errors.length === 0

  async function save() {
    setSaving(true)
    try {
      const size = Number(sizeMb)
      await api('releases', {
        method: 'POST',
        body: {
          channel,
          version: version.trim(),
          versionCode: codeNum,
          downloadUrl: url.trim(),
          ...(sha.trim() ? { sha256: sha.trim() } : {}),
          ...(size > 0 ? { sizeBytes: Math.round(size * 1048576) } : {}),
          notes: notes.split('\n').map((n) => n.trim()).filter(Boolean),
          published: publish,
        },
      })
      toast.success(publish ? `${version} published — phones will see it within a minute.` : `${version} saved as a draft.`)
      setVersion('')
      setCode('')
      setSha('')
      setSizeMb('')
      setNotes('')
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
        <CardTitle className="flex items-center gap-2">
          <Plus className="size-5" /> Add a new version
        </CardTitle>
        <CardDescription>Do this right after you upload a new APK to GitHub (or a new version to Google Play).</CardDescription>
      </CardHeader>
      <CardContent className="grid gap-4">
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="grid gap-1.5">
            <Label>Which version of the app?</Label>
            <NativeSelect
              value={channel}
              onChange={(e) => {
                const ch = e.target.value as AppReleaseRow['channel']
                setChannel(ch)
                if (ch === 'play' && !url) setUrl(PLAY_URL)
              }}
            >
              <option value="direct">Website (APK) version</option>
              <option value="play">Google Play version</option>
            </NativeSelect>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="grid gap-1.5">
              <Label>Version</Label>
              <Input value={version} onChange={(e) => setVersion(e.target.value)} placeholder="1.0.2" />
            </div>
            <div className="grid gap-1.5">
              <Label>Version code</Label>
              <Input inputMode="numeric" value={code} onChange={(e) => setCode(e.target.value)} placeholder="3" />
            </div>
          </div>
          <div className="grid gap-1.5 sm:col-span-2">
            <Label>Download link</Label>
            <Input value={url} onChange={(e) => setUrl(e.target.value)} placeholder="https://github.com/bolajigr8/readin-releases/releases/download/v1.0.2/readin-1.0.2-universal.apk" />
          </div>
          <div className="grid gap-1.5">
            <Label>SHA-256 (optional)</Label>
            <Input value={sha} onChange={(e) => setSha(e.target.value)} placeholder="64 letters and numbers" />
          </div>
          <div className="grid gap-1.5">
            <Label>Size in MB (optional)</Label>
            <Input inputMode="decimal" value={sizeMb} onChange={(e) => setSizeMb(e.target.value)} placeholder="85.5" />
          </div>
          <div className="grid gap-1.5 sm:col-span-2">
            <Label>What&rsquo;s new (one point per line)</Label>
            <textarea
              className="min-h-24 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-xs outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder={'Premium reminders\nFaster library'}
            />
          </div>
        </div>
        <label className="flex items-center gap-2 text-sm">
          <Switch checked={publish} onCheckedChange={setPublish} aria-label="Publish now" />
          Publish now (phones see it within a minute)
        </label>
        {errors.length > 0 && (
          <Callout tone="warning" title="Please fix">
            <ul className="list-disc pl-5">
              {errors.map((e) => (
                <li key={e}>{e}</li>
              ))}
            </ul>
          </Callout>
        )}
        <Explain title="Where do I find these?">
          <p>
            <strong>Version, version code, SHA-256 and size</strong> are in the <code>RELEASE-NOTES-….txt</code> file next to the APKs
            (in <code>mobile/build/release/&lt;version&gt;/</code>). The version code is the number after the &ldquo;+&rdquo;, e.g.
            1.0.2+3 → version 1.0.2, code 3.
          </p>
          <p>
            <strong>Download link:</strong> on GitHub open the release, right-click the <em>universal</em> APK → Copy link. For the
            Google Play version use the Play Store page of ReadIn.
          </p>
          <p>
            <strong>What phones do:</strong> people with an older version see a friendly &ldquo;new version&rdquo; banner on the Home
            screen (never while reading). A <strong>required update</strong> shows a full screen instead &mdash; switch that on only
            for important fixes. If your server can&rsquo;t be reached, nobody is ever blocked.
          </p>
        </Explain>
      </CardContent>
      <CardFooter className="justify-end">
        <Button onClick={save} disabled={!ready || saving}>
          {saving ? <Loader2 className="animate-spin" /> : <Save />} {publish ? 'Publish version' : 'Save draft'}
        </Button>
      </CardFooter>
    </Card>
  )
}
