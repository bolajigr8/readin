/**
 * Gutendex is a free JSON API for Project Gutenberg books.
 * No API key required. https://gutendex.com
 */

export interface GutenbergAuthor {
  name: string
  birth_year: number | null
  death_year: number | null
}

export interface GutenbergBook {
  id: number
  title: string
  authors: GutenbergAuthor[]
  subjects: string[]
  bookshelves: string[]
  languages: string[]
  copyright: boolean | null
  media_type: string
  formats: Record<string, string>
  download_count: number
}

export interface GutenbergResponse {
  count: number
  next: string | null
  previous: string | null
  results: GutenbergBook[]
}

const BASE_URL = 'https://gutendex.com'

/**
 * Format author name from "Lastname, Firstname" to "Firstname Lastname".
 */
export function formatAuthorName(name: string): string {
  const parts = name.split(',').map((s) => s.trim())
  if (parts.length === 2) return `${parts[1]} ${parts[0]}`
  return name
}

/**
 * Get the best EPUB download URL from a book's formats.
 */
export function getEpubUrl(formats: Record<string, string>): string | null {
  return formats['application/epub+zip'] ?? formats['application/epub'] ?? null
}

/**
 * Get the cover image URL from a book's formats.
 */
export function getCoverUrl(formats: Record<string, string>): string {
  return (
    formats['image/jpeg'] ??
    `https://www.gutenberg.org/cache/epub/0/pg0.cover.medium.jpg`
  )
}

/**
 * Search books by query string.
 */
export async function searchBooks(
  query: string,
  page = 1,
): Promise<GutenbergResponse> {
  const params = new URLSearchParams({
    search: query,
    languages: 'en',
    page: String(page),
  })
  const res = await fetch(`${BASE_URL}/books?${params.toString()}`)
  if (!res.ok) throw new Error(`Gutendex error: ${res.status}`)
  return res.json() as Promise<GutenbergResponse>
}

/**
 * Browse books by topic/shelf.
 */
export async function browseBooks(
  topic: string,
  page = 1,
): Promise<GutenbergResponse> {
  const params = new URLSearchParams({
    topic,
    languages: 'en',
    page: String(page),
  })
  const res = await fetch(`${BASE_URL}/books?${params.toString()}`)
  if (!res.ok) throw new Error(`Gutendex error: ${res.status}`)
  return res.json() as Promise<GutenbergResponse>
}

/**
 * Get top downloaded books.
 */
export async function getPopularBooks(page = 1): Promise<GutenbergResponse> {
  const params = new URLSearchParams({
    languages: 'en',
    page: String(page),
  })
  const res = await fetch(`${BASE_URL}/books?${params.toString()}`)
  if (!res.ok) throw new Error(`Gutendex error: ${res.status}`)
  return res.json() as Promise<GutenbergResponse>
}

/**
 * Get a single book by Gutenberg ID.
 */
export async function getBook(id: number): Promise<GutenbergBook> {
  const res = await fetch(`${BASE_URL}/books/${id}`)
  if (!res.ok) throw new Error(`Gutendex error: ${res.status}`)
  return res.json() as Promise<GutenbergBook>
}

// Curated categories shown on the Discover screen
export const CATEGORIES = [
  { id: 'adventure', label: 'Adventure', icon: '🗺️' },
  { id: 'fiction', label: 'Fiction', icon: '📖' },
  { id: 'mystery', label: 'Mystery', icon: '🔍' },
  { id: 'romance', label: 'Romance', icon: '💌' },
  { id: 'horror', label: 'Horror', icon: '🎃' },
  { id: 'philosophy', label: 'Philosophy', icon: '🧠' },
  { id: 'science', label: 'Science', icon: '🔬' },
  { id: 'history', label: 'History', icon: '🏛️' },
] as const
