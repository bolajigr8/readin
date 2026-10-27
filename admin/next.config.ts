import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  experimental: {
    agentFeedback: true,
  },
  // This panel is private and fully dynamic (every page needs a signed-in session
  // and live data). Cache Components / partial prefetching are meant for public,
  // mostly-static sites and would force "use cache" / <Suspense> rules on every
  // page, so they are switched OFF here.
  cacheComponents: false,
  partialPrefetching: false,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
