'use client'

// S5 — Team: owners add helpers to this admin panel and choose what each of them may do.

import { useState } from 'react'
import { Loader2, Pencil, RefreshCw, ShieldCheck, Trash2, UserPlus } from 'lucide-react'
import { toast } from 'sonner'
import { Callout, Explain } from '@/components/help'
import { PageHeader } from '@/components/page-header'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { NativeSelect } from '@/components/ui/native-select'
import { Skeleton } from '@/components/ui/skeleton'
import { Switch } from '@/components/ui/switch'
import { useStats } from '@/components/app-shell'
import { useApi } from '@/hooks/use-api'
import { api } from '@/lib/api'
import type { TeamMember, TeamPage } from '@/lib/types'
import { formatDateTime } from '@/lib/utils'

type Editing = { mode: 'add' } | { mode: 'edit'; member: TeamMember } | { mode: 'remove'; member: TeamMember }

export default function TeamPageView() {
  const team = useApi<TeamPage>('team')
  const { me } = useStats()
  const [editing, setEditing] = useState<Editing | null>(null)

  return (
    <>
      <PageHeader
        title="Team"
        description="Let other people help you run ReadIn — and choose exactly what each of them may do."
        actions={
          <div className="flex gap-2">
            <Button variant="outline" size="sm" onClick={team.reload}>
              <RefreshCw /> Refresh
            </Button>
            <Button size="sm" onClick={() => setEditing({ mode: 'add' })} disabled={!team.data}>
              <UserPlus /> Add team member
            </Button>
          </div>
        }
      />
      <div className="grid gap-4 [&>*]:min-w-0">
        <Explain title="How the team works">
          <p>
            <strong>Owner</strong> &mdash; can do everything, including this Team page. You are an owner. There must always be at
            least one owner.
          </p>
          <p>
            <strong>Admin</strong> &mdash; can only do what you tick for them (for example &ldquo;Support&rdquo;: look up users,
            confirm e-mails, switch accounts off, see payments). Admins can never change the team.
          </p>
          <p>
            The person must first <strong>sign up in the ReadIn app and confirm their e-mail</strong>; then add them here with that
            e-mail. They sign in to this panel with their own e-mail and password. You confirm every change with <em>your</em>{' '}
            password, and everything is written to the Audit log.
          </p>
          <p>
            <strong>Testers</strong> (people in your closed test) are not set here: open the person on the Users page and switch on
            &ldquo;Tester&rdquo;.
          </p>
        </Explain>

        {team.error && !team.data ? (
          <p className="text-sm text-destructive">{team.error}</p>
        ) : !team.data ? (
          <Skeleton className="h-40 w-full" />
        ) : (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <ShieldCheck className="size-5" /> Team members
              </CardTitle>
              <CardDescription>{team.data.items.length} people can open this panel.</CardDescription>
            </CardHeader>
            <CardContent className="grid gap-3">
              {team.data.items.map((m) => {
                const self = m.email === me?.email
                const locked = self || m.fixedOwner
                return (
                  <div key={m.id} className="grid gap-2 rounded-lg border p-4">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="font-medium break-all">{m.email}</span>
                      {m.role === 'owner' ? <Badge variant="info">Owner</Badge> : <Badge>Admin</Badge>}
                      {self && <Badge variant="secondary">You</Badge>}
                      {m.fixedOwner && <Badge variant="secondary">Set on the server</Badge>}
                      {m.disabled && <Badge variant="danger">Disabled</Badge>}
                    </div>
                    <p className="text-xs text-muted-foreground">
                      {m.displayName} · last sign-in {formatDateTime(m.lastLoginAt)}
                    </p>
                    {m.role === 'admin' && (
                      <p className="text-sm">
                        May:{' '}
                        {m.permissions.length === 0
                          ? 'nothing yet'
                          : m.permissions.map((p) => team.data!.permissions.find((x) => x.key === p)?.label ?? p).join(' · ')}
                      </p>
                    )}
                    {!locked && (
                      <div className="flex flex-wrap gap-2">
                        <Button size="sm" variant="outline" onClick={() => setEditing({ mode: 'edit', member: m })}>
                          <Pencil /> Change
                        </Button>
                        <Button size="sm" variant="outline" onClick={() => setEditing({ mode: 'remove', member: m })}>
                          <Trash2 className="text-destructive" /> Remove from team
                        </Button>
                      </div>
                    )}
                    {m.fixedOwner && (
                      <p className="text-xs text-muted-foreground">
                        This owner comes from the server setting ADMIN_EMAILS (your safety key) and can&rsquo;t be changed here.
                      </p>
                    )}
                  </div>
                )
              })}
            </CardContent>
          </Card>
        )}
      </div>
      {team.data && editing && (
        <MemberDialog
          editing={editing}
          page={team.data}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null)
            team.reload()
          }}
        />
      )}
    </>
  )
}

function MemberDialog({
  editing,
  page,
  onClose,
  onSaved,
}: {
  editing: Editing
  page: TeamPage
  onClose: () => void
  onSaved: () => void
}) {
  const member = editing.mode === 'add' ? null : editing.member
  const [email, setEmail] = useState('')
  const [role, setRole] = useState<'admin' | 'owner'>(member?.role ?? 'admin')
  const [perms, setPerms] = useState<string[]>(member?.permissions ?? page.presets.find((p) => p.key === 'support')?.permissions ?? [])
  const [password, setPassword] = useState('')
  const [saving, setSaving] = useState(false)

  const toggle = (key: string, on: boolean) => setPerms((l) => (on ? [...new Set([...l, key])] : l.filter((x) => x !== key)))
  const preset = page.presets.find((p) => p.permissions.length === perms.length && p.permissions.every((x) => perms.includes(x)))

  async function save() {
    setSaving(true)
    try {
      if (editing.mode === 'add') {
        await api('team', { method: 'POST', body: { email: email.trim(), role, permissions: role === 'admin' ? perms : [], password } })
        toast.success(`${email.trim()} added to the team.`)
      } else if (editing.mode === 'edit') {
        await api(`team/${editing.member.id}`, { method: 'PATCH', body: { role, permissions: role === 'admin' ? perms : [], password } })
        toast.success('Saved. Their new rights apply right away; they sign in again on their devices.')
      } else {
        await api(`team/${editing.member.id}`, { method: 'DELETE', body: { password } })
        toast.success(`${editing.member.email} is no longer in the team. Their ReadIn account stays.`)
      }
      onSaved()
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not save.')
    } finally {
      setSaving(false)
    }
  }

  const title =
    editing.mode === 'add' ? 'Add a team member' : editing.mode === 'edit' ? `Change ${editing.member.email}` : `Remove ${editing.member.email}?`
  const ready = password.length > 0 && (editing.mode !== 'add' || /.+@.+\..+/.test(email.trim()))

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>
            {editing.mode === 'remove'
              ? 'They can no longer open this panel. Their ReadIn account, books and notes stay as they are.'
              : 'Changes apply right away and are written to the Audit log.'}
          </DialogDescription>
        </DialogHeader>
        <div className="grid gap-4">
          {editing.mode === 'add' && (
            <div className="grid gap-1.5">
              <Label htmlFor="tm-email">Their e-mail (the one they use in the ReadIn app)</Label>
              <Input id="tm-email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="helper@example.com" />
            </div>
          )}
          {editing.mode !== 'remove' && (
            <>
              <div className="grid gap-1.5">
                <Label htmlFor="tm-role">Role</Label>
                <NativeSelect id="tm-role" value={role} onChange={(e) => setRole(e.target.value as 'admin' | 'owner')}>
                  <option value="admin">Admin — only what you tick below</option>
                  <option value="owner">Owner — everything, including this Team page</option>
                </NativeSelect>
              </div>
              {role === 'owner' && (
                <Callout tone="warning" title="Owners have full control">
                  An owner can change prices, payments and the team — including you. Only choose this for someone you trust
                  completely.
                </Callout>
              )}
              {role === 'admin' && (
                <div className="grid gap-2">
                  <Label htmlFor="tm-preset">Quick choice</Label>
                  <NativeSelect
                    id="tm-preset"
                    value={preset?.key ?? 'custom'}
                    onChange={(e) => {
                      const p = page.presets.find((x) => x.key === e.target.value)
                      if (p) setPerms(p.permissions)
                    }}
                  >
                    {page.presets.map((p) => (
                      <option key={p.key} value={p.key}>
                        {p.label}
                      </option>
                    ))}
                    <option value="custom">Custom (tick below)</option>
                  </NativeSelect>
                  <div className="grid gap-2 rounded-lg border p-3">
                    {page.permissions.map((p) => (
                      <label key={p.key} className="flex items-center justify-between gap-3 text-sm">
                        <span>{p.label}</span>
                        <Switch checked={perms.includes(p.key)} onCheckedChange={(on) => toggle(p.key, on)} aria-label={p.label} />
                      </label>
                    ))}
                  </div>
                </div>
              )}
            </>
          )}
          <div className="grid gap-1.5">
            <Label htmlFor="tm-pw">Your password (to confirm)</Label>
            <Input id="tm-pw" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} />
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button variant={editing.mode === 'remove' ? 'destructive' : 'default'} onClick={save} disabled={!ready || saving}>
            {saving && <Loader2 className="animate-spin" />}
            {editing.mode === 'add' ? 'Add to team' : editing.mode === 'edit' ? 'Save' : 'Remove from team'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
