import type { NextConfig } from 'next'

// The public website readin.micbol.org (DECISIONS #18): a STATIC export (`out/`) hosted free on
// Cloudflare Pages. No server features (cookies, rewrites, server actions, image optimisation).
const nextConfig: NextConfig = {
  output: 'export',
  images: { unoptimized: true },
  // Public, fully static site → no Cache Components / partial prefetching (they need a server).
  cacheComponents: false,
  partialPrefetching: false,
  turbopack: {
    rules: {
      '*.css': {
        loaders: ['@tailwindcss/turbopack'],
        as: '*.css',
      },
    },
  },
}

export default nextConfig
