'use client'

import { useCallback, useEffect, useState } from 'react'
import { api } from '@/lib/api'

interface Result<T> {
  key: string
  data?: T
  error?: string
}

/**
 * GET data from the admin API.
 *  • keeps showing the previous data while a new request is running (no flicker)
 *  • `reload()` fetches again
 *  • pass `null` to skip
 */
export function useApi<T>(path: string | null) {
  const [version, setVersion] = useState(0)
  const [res, setRes] = useState<Result<T> | null>(null)
  const key = path === null ? null : `${path}#${version}`

  useEffect(() => {
    if (path === null || key === null) return
    let cancelled = false
    api<T>(path)
      .then((data) => {
        if (!cancelled) setRes({ key, data })
      })
      .catch((e: unknown) => {
        if (!cancelled) {
          setRes((prev) => ({ key, data: prev?.data, error: e instanceof Error ? e.message : 'Something went wrong.' }))
        }
      })
    return () => {
      cancelled = true
    }
  }, [key, path])

  const reload = useCallback(() => setVersion((v) => v + 1), [])

  return {
    data: res?.data,
    error: res !== null && res.key === key ? res.error : undefined,
    loading: key !== null && (res === null || res.key !== key),
    reload,
  }
}
