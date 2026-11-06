import type { Metadata, Viewport } from 'next'
import { GeistSans } from 'geist/font/sans'
import { Fraunces } from 'next/font/google'
import { Providers } from '@/components/providers'
import './globals.css'

// Bookish serif for headings (downloaded at BUILD time and served from our own site — no
// request to Google when someone visits).
const fraunces = Fraunces({ subsets: ['latin'], style: ['normal', 'italic'], variable: '--font-fraunces', display: 'swap' })

const SITE = 'https://readin.micbol.org'

export const metadata: Metadata = {
  metadataBase: new URL(SITE),
  title: { default: 'ReadIn — fall in love with reading again', template: '%s — ReadIn' },
  description:
    'ReadIn is a beautiful reading app for Android: EPUB, PDF and documents, thousands of free classics, notes and highlights, a daily reading habit and read-aloud — even offline.',
  icons: {
    icon: [
      { url: '/img/favicon-32.png', sizes: '32x32', type: 'image/png' },
      { url: '/img/favicon-64.png', sizes: '64x64', type: 'image/png' },
    ],
    apple: '/img/apple-touch-icon.png',
  },
  openGraph: {
    type: 'website',
    url: SITE,
    siteName: 'ReadIn',
    title: 'ReadIn — fall in love with reading again',
    description: 'Read EPUB, PDF and documents, discover free classics, keep notes and build a reading habit.',
    images: [{ url: '/img/og.png', width: 1200, height: 630, alt: 'ReadIn' }],
  },
}

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#fffaf4' },
    { media: '(prefers-color-scheme: dark)', color: '#0b0806' },
  ],
}

// Runs before the first paint: saved choice ("light"/"dark") or the phone's setting.
const themeScript = `(function(){try{var t=localStorage.getItem('readin-theme');var d=t==='dark'||(t!=='light'&&window.matchMedia('(prefers-color-scheme: dark)').matches);document.documentElement.classList.toggle('dark',d);}catch(e){}})();`

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning className={`${GeistSans.variable} ${fraunces.variable} antialiased`}>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
        {/* Without JavaScript the scroll-in animations never run — show everything instead. */}
        <noscript>
          <style>{'[style*="opacity:0"]{opacity:1!important;transform:none!important}'}</style>
        </noscript>
      </head>
      <body className="min-h-screen overflow-x-hidden">
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
