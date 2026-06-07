import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import AsyncStorage from '@react-native-async-storage/async-storage'

interface SettingsState {
  defaultFontSize: number
  defaultFontFamily: 'serif' | 'sans-serif'
  defaultReaderTheme: 'light' | 'dark' | 'sepia'
  notificationsEnabled: boolean
  autoDownloadEpub: boolean
}

interface SettingsActions {
  setDefaultFontSize: (size: number) => void
  setDefaultFontFamily: (family: 'serif' | 'sans-serif') => void
  setDefaultReaderTheme: (theme: 'light' | 'dark' | 'sepia') => void
  setNotificationsEnabled: (enabled: boolean) => void
  setAutoDownloadEpub: (enabled: boolean) => void
  reset: () => void
}

const DEFAULTS: SettingsState = {
  defaultFontSize: 17,
  defaultFontFamily: 'sans-serif',
  defaultReaderTheme: 'dark',
  notificationsEnabled: true,
  autoDownloadEpub: true,
}

export const useSettingsStore = create<SettingsState & SettingsActions>()(
  persist(
    (set) => ({
      ...DEFAULTS,
      setDefaultFontSize: (size) =>
        set({ defaultFontSize: Math.min(28, Math.max(12, size)) }),
      setDefaultFontFamily: (family) => set({ defaultFontFamily: family }),
      setDefaultReaderTheme: (theme) => set({ defaultReaderTheme: theme }),
      setNotificationsEnabled: (enabled) =>
        set({ notificationsEnabled: enabled }),
      setAutoDownloadEpub: (enabled) => set({ autoDownloadEpub: enabled }),
      reset: () => set(DEFAULTS),
    }),
    {
      name: '@readin/settings',
      storage: createJSONStorage(() => AsyncStorage),
    },
  ),
)
