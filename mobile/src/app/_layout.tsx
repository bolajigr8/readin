import React, { useEffect, useState } from 'react'
import { Stack, router } from 'expo-router'
import { GestureHandlerRootView } from 'react-native-gesture-handler'
import { SafeAreaProvider } from 'react-native-safe-area-context'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import * as SplashScreen from 'expo-splash-screen'
import * as Notifications from 'expo-notifications'
import Constants from 'expo-constants'
import AsyncStorage from '@react-native-async-storage/async-storage'
import {
  useFonts,
  Inter_400Regular,
  Inter_500Medium,
  Inter_600SemiBold,
  Inter_700Bold,
} from '@expo-google-fonts/inter'

import { useAuthStore } from '@/store/authStore'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import api from '@/services/api'
import '../../global.css'
import { DrawerProvider } from '@/context/DrawerContext'
import { AppDrawer } from '@/components/AppDrawer'
import { ToastProvider } from '@/context/ToastContext'
import { MiniPlayer } from '@/components/MiniPlayer'

// ── Onboarding key ────────────────────────────────────────────────────────────
// Defined here (not imported from onboarding.tsx) to avoid importing a route
// file into the layout, which can cause Metro bundling issues.
const ONBOARDING_KEY = '@readin/onboarding_complete'

// ── Detect Expo Go ────────────────────────────────────────────────────────────
// Push notifications were removed from Expo Go in SDK 53.
// We skip all notification setup when running in Expo Go.
// In a real development build or production, this is false and notifications work.
const IS_EXPO_GO = Constants.executionEnvironment === 'storeClient'

// ── Splash screen ─────────────────────────────────────────────────────────────
SplashScreen.preventAutoHideAsync()

// ── Notification handler (skipped in Expo Go) ─────────────────────────────────
if (!IS_EXPO_GO) {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowAlert: true,
      shouldPlaySound: true,
      shouldSetBadge: false,
      shouldShowBanner: true,
      shouldShowList: true,
    }),
  })
}

// ── React Query client ────────────────────────────────────────────────────────
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      staleTime: 1000 * 60 * 2,
    },
  },
})

// ── Push token registration (skipped in Expo Go) ──────────────────────────────
async function registerPushToken(): Promise<void> {
  if (IS_EXPO_GO) return

  try {
    const { status: existingStatus } = await Notifications.getPermissionsAsync()
    let finalStatus = existingStatus

    if (existingStatus !== 'granted') {
      const { status } = await Notifications.requestPermissionsAsync()
      finalStatus = status
    }

    if (finalStatus !== 'granted') return

    const tokenData = await Notifications.getExpoPushTokenAsync()
    if (tokenData.data) {
      await api.put('/users/push-token', {
        expoPushToken: tokenData.data,
      })
    }
  } catch {
    // Non-critical — never crash the app over push token registration
  }
}

// ── Auth gate ─────────────────────────────────────────────────────────────────
function AuthGate({ children }: { children: React.ReactNode }) {
  const hydrate = useAuthStore((s) => s.hydrate)
  const isHydrated = useAuthStore((s) => s.isHydrated)
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated)

  // Onboarding state — checked in parallel with auth hydration
  const [onboardingChecked, setOnboardingChecked] = useState(false)
  const [needsOnboarding, setNeedsOnboarding] = useState(false)

  useEffect(() => {
    // Both run at the same time — no sequential waiting
    hydrate()

    AsyncStorage.getItem(ONBOARDING_KEY)
      .then((value) => {
        // null means the key was never set → user has never seen onboarding
        setNeedsOnboarding(value === null)
        setOnboardingChecked(true)
      })
      .catch(() => {
        // If AsyncStorage fails for any reason, skip onboarding gracefully
        setNeedsOnboarding(false)
        setOnboardingChecked(true)
      })
  }, [hydrate])

  useEffect(() => {
    // Only route once BOTH checks are done
    if (!onboardingChecked || !isHydrated) return

    if (needsOnboarding) {
      // First ever launch — show onboarding slides
      router.replace('/onboarding')
    } else if (isAuthenticated) {
      // Returning logged-in user — go straight to app
      registerPushToken()
      router.replace('/(tabs)')
    } else {
      // Returning user, not logged in — show login
      router.replace('/(auth)/login')
    }
  }, [onboardingChecked, isHydrated, needsOnboarding, isAuthenticated])

  // Show spinner while either check is still pending
  if (!onboardingChecked || !isHydrated) {
    return <LoadingSpinner fullScreen label='Loading ReadIn...' />
  }

  return <>{children}</>
}

// ── Root layout ───────────────────────────────────────────────────────────────
export default function RootLayout() {
  const [fontsLoaded, fontError] = useFonts({
    Inter_400Regular,
    Inter_500Medium,
    Inter_600SemiBold,
    Inter_700Bold,
  })

  useEffect(() => {
    if (fontsLoaded || fontError) {
      SplashScreen.hideAsync()
    }
  }, [fontsLoaded, fontError])

  if (!fontsLoaded && !fontError) return null

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <QueryClientProvider client={queryClient}>
          <ToastProvider>
            <DrawerProvider>
              <AppDrawer />
              <MiniPlayer />

              <AuthGate>
                <Stack screenOptions={{ headerShown: false }}>
                  {/* Onboarding appears instantly — no animation needed coming in */}
                  <Stack.Screen
                    name='onboarding'
                    options={{ animation: 'none' }}
                  />

                  {/* Auth screens slide UP from the bottom — feels like a "new chapter" starting */}
                  <Stack.Screen
                    name='(auth)'
                    options={{ animation: 'fade_from_bottom' }}
                  />

                  {/* Tabs fade in softly after login */}
                  <Stack.Screen name='(tabs)' options={{ animation: 'fade' }} />

                  {/* Upload modal — slides up from bottom */}
                  <Stack.Screen
                    name='upload'
                    options={{
                      presentation: 'modal',
                      animation: 'slide_from_bottom',
                    }}
                  />

                  {/* Reader — full screen, no header, hides tab bar automatically
      because it lives outside (tabs) */}
                  <Stack.Screen
                    name='reader/[bookId]'
                    options={{ animation: 'fade' }}
                  />
                </Stack>
              </AuthGate>
            </DrawerProvider>
          </ToastProvider>{' '}
        </QueryClientProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  )
}
