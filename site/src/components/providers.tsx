'use client'

import { MotionConfig } from 'motion/react'

/** Every animation follows the phone/computer "reduce motion" setting. */
export function Providers({ children }: { children: React.ReactNode }) {
  return <MotionConfig reducedMotion="user">{children}</MotionConfig>
}
