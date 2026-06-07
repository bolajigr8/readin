import { create } from 'zustand'
import * as SecureStore from 'expo-secure-store'
import { STORAGE_KEYS, clearAllTokens, getAccessToken } from '@/services/api'
import api from '@/services/api'

// ── Types ─────────────────────────────────────────────────────────────────────

export interface User {
  id: string
  email: string
  displayName: string
  avatar: string
  plan: 'free' | 'premium'
  isEmailVerified: boolean
}

interface AuthState {
  user: User | null
  accessToken: string | null
  isLoading: boolean
  isAuthenticated: boolean
  isHydrated: boolean
}

interface AuthActions {
  login: (
    user: User,
    accessToken: string,
    refreshToken: string,
  ) => Promise<void>
  logout: () => Promise<void>
  setUser: (user: User) => void
  hydrate: () => Promise<void>
}

// ── Store ─────────────────────────────────────────────────────────────────────

export const useAuthStore = create<AuthState & AuthActions>((set, get) => ({
  user: null,
  accessToken: null,
  isLoading: false,
  isAuthenticated: false,
  isHydrated: false,

  login: async (user, accessToken, refreshToken) => {
    await Promise.all([
      SecureStore.setItemAsync(STORAGE_KEYS.ACCESS_TOKEN, accessToken),
      SecureStore.setItemAsync(STORAGE_KEYS.REFRESH_TOKEN, refreshToken),
      SecureStore.setItemAsync(STORAGE_KEYS.USER, JSON.stringify(user)),
    ])

    set({
      user,
      accessToken,
      isAuthenticated: true,
      isLoading: false,
    })
  },

  logout: async () => {
    set({ isLoading: true })

    try {
      const token = await getAccessToken()
      const refreshToken = await SecureStore.getItemAsync(
        STORAGE_KEYS.REFRESH_TOKEN,
      )
      if (token && refreshToken) {
        // Fire and forget — don't block logout on API call
        api.post('/auth/logout', { refreshToken }).catch(() => undefined)
      }
    } finally {
      await clearAllTokens()
      set({
        user: null,
        accessToken: null,
        isAuthenticated: false,
        isLoading: false,
      })
    }
  },

  setUser: (user) => set({ user }),

  hydrate: async () => {
    set({ isLoading: true })
    try {
      const [token, userJson] = await Promise.all([
        getAccessToken(),
        SecureStore.getItemAsync(STORAGE_KEYS.USER),
      ])

      if (token && userJson) {
        const user = JSON.parse(userJson) as User
        set({
          user,
          accessToken: token,
          isAuthenticated: true,
        })
      }
    } catch {
      await clearAllTokens()
      set({ user: null, accessToken: null, isAuthenticated: false })
    } finally {
      set({ isLoading: false, isHydrated: true })
    }
  },
}))
