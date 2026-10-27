import { Info, Lightbulb, TriangleAlert } from 'lucide-react'
import { cn } from '@/lib/utils'

/** "What does this do?" — a short explanation that opens with one click. */
export function Explain({
  title = 'What does this do?',
  children,
  className,
}: {
  title?: string
  children: React.ReactNode
  className?: string
}) {
  return (
    <details className={cn('group rounded-lg border bg-muted/40 px-3 py-2 text-sm', className)}>
      <summary className="flex cursor-pointer list-none items-center gap-2 font-medium text-foreground/80 select-none">
        <Info className="size-4 shrink-0 text-primary" />
        {title}
        <span className="ml-auto text-xs text-muted-foreground group-open:hidden">Show</span>
        <span className="ml-auto hidden text-xs text-muted-foreground group-open:inline">Hide</span>
      </summary>
      <div className="mt-2 grid gap-2 leading-relaxed text-muted-foreground">{children}</div>
    </details>
  )
}

/** A boxed note: a tip, a warning or plain information. */
export function Callout({
  tone = 'info',
  title,
  children,
}: {
  tone?: 'info' | 'tip' | 'warning'
  title?: string
  children: React.ReactNode
}) {
  const Icon = tone === 'warning' ? TriangleAlert : tone === 'tip' ? Lightbulb : Info
  const colors =
    tone === 'warning'
      ? 'border-amber-500/40 bg-amber-500/10'
      : tone === 'tip'
        ? 'border-emerald-500/40 bg-emerald-500/10'
        : 'border-sky-500/40 bg-sky-500/10'
  return (
    <div className={cn('flex gap-3 rounded-lg border p-3 text-sm leading-relaxed', colors)}>
      <Icon className="mt-0.5 size-4 shrink-0" />
      <div className="grid gap-1">
        {title && <div className="font-medium">{title}</div>}
        <div className="text-muted-foreground">{children}</div>
      </div>
    </div>
  )
}
