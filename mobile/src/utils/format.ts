/**
 * Format bytes into a human-readable file size string.
 * Examples: 512 → "512 B", 1536 → "1.5 KB", 2097152 → "2.0 MB"
 */
export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B'
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

/**
 * Return a time-appropriate greeting for the current hour.
 */
export function getGreeting(): string {
  const hour = new Date().getHours()
  if (hour < 12) return 'Good morning'
  if (hour < 17) return 'Good afternoon'
  return 'Good evening'
}

/**
 * Format a date string to "May 21" style.
 */
export function formatDate(dateString: string): string {
  return new Date(dateString).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
  })
}

/**
 * Derive a deterministic cover fallback color from the book title.
 * Same title always produces the same color.
 */
const FALLBACK_COLORS = [
  '#F97316',
  '#FBBF24',
  '#22C55E',
  '#3B82F6',
  '#A855F7',
  '#EF4444',
  '#06B6D4',
  '#F472B6',
] as const

export function getCoverColor(title: string): string {
  const code = title.charCodeAt(0) ?? 65
  return FALLBACK_COLORS[code % FALLBACK_COLORS.length] ?? '#F97316'
}

/**
 * Get up to 2 uppercase initials from a title.
 * "Pride and Prejudice" → "PP", "Frankenstein" → "FR" (wait actually "F")
 * Let me do: first 2 chars of first word for single-word titles
 * "Frankenstein" → "Fr", "Pride and Prejudice" → "PP"
 */
export function getTitleInitials(title: string): string {
  const words = title.trim().split(/\s+/)
  if (words.length === 1) {
    // Single word — first 2 characters
    return title.slice(0, 2).toUpperCase()
  }
  // Multi-word — first letter of first two words
  return words
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('')
}
