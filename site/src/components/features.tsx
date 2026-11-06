import { BookOpen, Download, Flame, Globe2, Headphones, Highlighter, Share2, Type } from 'lucide-react'
import { Reveal } from './reveal'

const FORMATS = ['EPUB', 'PDF', 'DOCX', 'XLSX', 'PPTX', 'TXT', 'Markdown', 'RTF', 'HTML', 'ODT', 'CSV']

/** Endless strip of supported formats. */
export function FormatMarquee() {
  const row = [...FORMATS, ...FORMATS]
  return (
    <div className="relative overflow-hidden border-y border-line bg-bg-2/60 py-5" aria-label="Supported file types">
      <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-20 bg-gradient-to-r from-bg to-transparent" />
      <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-20 bg-gradient-to-l from-bg to-transparent" />
      <div className="marquee flex w-max gap-10 whitespace-nowrap">
        {row.map((f, i) => (
          <span key={i} className="flex items-center gap-3 font-serif text-xl italic text-soft" aria-hidden={i >= FORMATS.length}>
            <BookOpen className="h-4 w-4 not-italic text-brand/70" /> {f}
          </span>
        ))}
      </div>
    </div>
  )
}

function Tile({
  children,
  className = '',
  delay = 0,
}: {
  children: React.ReactNode
  className?: string
  delay?: number
}) {
  return (
    <Reveal delay={delay} className={`group relative overflow-hidden rounded-3xl border border-line bg-card p-7 transition duration-300 hover:-translate-y-1 hover:shadow-[var(--shadow)] ${className}`}>
      {children}
    </Reveal>
  )
}

function TileTitle({ icon: Icon, title, text }: { icon: typeof Type; title: string; text: string }) {
  return (
    <>
      <div className="mb-4 grid h-11 w-11 place-items-center rounded-2xl bg-brand/12 text-brand">
        <Icon className="h-5 w-5" />
      </div>
      <h3 className="font-serif text-2xl font-semibold text-ink">{title}</h3>
      <p className="mt-2 max-w-md leading-relaxed text-muted">{text}</p>
    </>
  )
}

export function Features() {
  return (
    <section id="features" className="scroll-mt-20 py-24">
      <div className="mx-auto max-w-6xl px-5">
        <Reveal className="mx-auto max-w-2xl text-center">
          <p className="text-sm font-semibold uppercase tracking-[0.2em] text-brand">Everything a reader needs</p>
          <h2 className="mt-3 font-serif text-4xl font-semibold tracking-tight text-ink sm:text-5xl">
            One app for every book <span className="italic text-gradient">you love</span>
          </h2>
        </Reveal>

        <div className="mt-14 grid gap-5 md:grid-cols-6">
          {/* Reader customisation — big tile */}
          <Tile className="md:col-span-4">
            <TileTitle icon={Type} title="A reader made for you" text="Pick your font, size, spacing, margins and theme. Turn pages or scroll. Your place is always saved." />
            <div className="mt-6 flex flex-wrap gap-2.5">
              {[
                ['Light', 'bg-white text-[#3b2a1e] border-[#eadfce]'],
                ['Sepia', 'bg-[#f4e7d3] text-[#4a3523] border-[#e3cfb2]'],
                ['Night', 'bg-[#141110] text-[#e8dccd] border-[#2a2420]'],
              ].map(([n, c]) => (
                <span key={n} className={`rounded-xl border px-4 py-2 text-sm font-medium ${c}`}>{n}</span>
              ))}
              {['Merriweather', 'Literata', 'Lora'].map((f) => (
                <span key={f} className="rounded-xl border border-line px-4 py-2 font-serif text-sm text-muted">{f}</span>
              ))}
            </div>
          </Tile>

          {/* Read-aloud */}
          <Tile className="md:col-span-2" delay={0.08}>
            <TileTitle icon={Headphones} title="Read-aloud" text="ReadIn reads to you, with controls on your lock screen." />
            <div className="mt-6 flex h-14 items-end gap-1.5" aria-hidden="true">
              {Array.from({ length: 18 }).map((_, i) => (
                <span
                  key={i}
                  className="sound-bar w-2 flex-1 rounded-full bg-gradient-to-t from-brand to-amber"
                  style={{ height: `${30 + ((i * 37) % 70)}%`, animationDelay: `${(i % 6) * 0.12}s` }}
                />
              ))}
            </div>
          </Tile>

          {/* Habit tracker */}
          <Tile className="md:col-span-3" delay={0.05}>
            <TileTitle icon={Flame} title="A gentle daily habit" text="Set a goal, get a friendly reminder and watch your streak grow." />
            <div className="mt-6 grid grid-cols-7 gap-1.5" aria-hidden="true">
              {Array.from({ length: 28 }).map((_, i) => {
                const done = [0, 1, 2, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 22, 23].includes(i)
                return (
                  <span
                    key={i}
                    className={`aspect-square rounded-md ${done ? 'bg-brand' : 'bg-line'} ${i >= 21 && done ? 'opacity-100' : done ? 'opacity-70' : ''}`}
                  />
                )
              })}
            </div>
          </Tile>

          {/* Notes & highlights */}
          <Tile className="md:col-span-3" delay={0.1}>
            <TileTitle icon={Highlighter} title="Notes that stay with you" text="Highlight, bookmark and write notes. Turn a favourite line into a beautiful quote card." />
            <figure className="mt-6 rounded-2xl border border-line bg-bg-2 p-5">
              <blockquote className="font-serif text-lg italic leading-relaxed text-ink">
                “I declare after all there is no enjoyment like reading!”
              </blockquote>
              <figcaption className="mt-2 text-sm text-soft">— Jane Austen, Pride and Prejudice · saved to your notes</figcaption>
            </figure>
          </Tile>

          {/* Free classics */}
          <Tile className="md:col-span-2" delay={0.05}>
            <TileTitle icon={Globe2} title="Free classics" text="Thousands of public-domain books from Project Gutenberg, one tap away." />
            <div className="mt-6 flex items-end gap-1.5" aria-hidden="true">
              {[
                ['h-24', 'bg-[#9a3412]'], ['h-28', 'bg-[#f97316]'], ['h-20', 'bg-[#78350f]'], ['h-32', 'bg-[#f59e0b]'],
                ['h-24', 'bg-[#c2410c]'], ['h-28', 'bg-[#fdba74]'], ['h-20', 'bg-[#7c2d12]'],
              ].map(([h, c], i) => (
                <span key={i} className={`${h} w-7 rounded-t-md ${c} shadow-sm transition duration-300 group-hover:-translate-y-1`} style={{ transitionDelay: `${i * 40}ms` }} />
              ))}
            </div>
          </Tile>

          {/* Import */}
          <Tile className="md:col-span-2" delay={0.1}>
            <TileTitle icon={Share2} title="Import in seconds" text="Share a file from WhatsApp, e-mail or your files straight into ReadIn." />
          </Tile>

          {/* Offline */}
          <Tile className="md:col-span-2" delay={0.15}>
            <TileTitle icon={Download} title="Made for real life" text="Books live on your phone and open offline — perfect for travel and slow data." />
          </Tile>
        </div>
      </div>
    </section>
  )
}
