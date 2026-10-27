'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { BookOpen, Loader2 } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

export default function LoginPage() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [slow, setSlow] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // The API can be asleep on a free host: after a few seconds say so.
  useEffect(() => {
    if (!busy) return
    const t = setTimeout(() => setSlow(true), 4000)
    return () => clearTimeout(t)
  }, [busy])

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setBusy(true)
    setSlow(false)
    setError(null)
    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-requested-with': 'admin' },
        body: JSON.stringify({ email, password }),
        cache: 'no-store',
      })
      const body = (await res.json().catch(() => null)) as { message?: string } | null
      if (!res.ok) {
        setError(body?.message ?? 'Sign-in failed.')
        setBusy(false)
        return
      }
      router.replace('/dashboard')
    } catch {
      setError('Network error — check your connection.')
      setBusy(false)
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center p-4">
      <Card className="w-full max-w-sm">
        <CardHeader className="items-center text-center">
          <div className="mb-2 flex size-12 items-center justify-center rounded-xl bg-primary text-primary-foreground">
            <BookOpen className="size-6" />
          </div>
          <CardTitle className="text-xl">ReadIn Admin</CardTitle>
          <CardDescription>Sign in with your administrator account</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={submit} className="grid gap-4">
            <div className="grid gap-2">
              <Label htmlFor="email">E-mail</Label>
              <Input
                id="email"
                type="email"
                autoComplete="username"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={busy}
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="password">Password</Label>
              <Input
                id="password"
                type="password"
                autoComplete="current-password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                disabled={busy}
              />
            </div>
            {error && (
              <p role="alert" className="text-sm text-destructive">
                {error}
              </p>
            )}
            <Button type="submit" disabled={busy || !email || !password}>
              {busy && <Loader2 className="animate-spin" />}
              {busy ? 'Signing in…' : 'Sign in'}
            </Button>
            {slow && (
              <p className="text-center text-xs text-muted-foreground">
                The server is waking up — this can take up to a minute.
              </p>
            )}
          </form>
        </CardContent>
      </Card>
    </main>
  )
}
