import React, { useState, useRef, useEffect } from 'react'
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  Animated,
} from 'react-native'
import { router } from 'expo-router'
import { SafeAreaView } from 'react-native-safe-area-context'
import * as WebBrowser from 'expo-web-browser'
import * as Google from 'expo-auth-session/providers/google'
import * as AuthSession from 'expo-auth-session'
import { Ionicons } from '@expo/vector-icons'

import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { useAuth } from '@/hooks/useAuth'
import api from '@/services/api'
import { THEME } from '@/constants/theme'
import type { User } from '@/store/authStore'

// Required — without this, the browser does not close after Google login
WebBrowser.maybeCompleteAuthSession()

interface FormState {
  email: string
  password: string
}

interface FormErrors {
  email?: string
  password?: string
  general?: string
}

function validate(form: FormState): FormErrors {
  const errors: FormErrors = {}
  if (!form.email.trim()) {
    errors.email = 'Email is required'
  } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) {
    errors.email = 'Enter a valid email address'
  }
  if (!form.password) {
    errors.password = 'Password is required'
  }
  return errors
}

export default function LoginScreen() {
  const { login } = useAuth()

  const [form, setForm] = useState<FormState>({ email: '', password: '' })
  const [errors, setErrors] = useState<FormErrors>({})
  const [isLoading, setIsLoading] = useState(false)
  const [isGoogleLoading, setIsGoogleLoading] = useState(false)

  // ── Entrance animations ───────────────────────────────────────────────────
  const headerAnim = useRef(new Animated.Value(0)).current
  const formAnim = useRef(new Animated.Value(0)).current
  const footerAnim = useRef(new Animated.Value(0)).current
  const headerSlide = useRef(new Animated.Value(24)).current
  const formSlide = useRef(new Animated.Value(24)).current
  const footerSlide = useRef(new Animated.Value(24)).current

  useEffect(() => {
    Animated.stagger(80, [
      Animated.parallel([
        Animated.timing(headerAnim, {
          toValue: 1,
          duration: 420,
          useNativeDriver: true,
        }),
        Animated.timing(headerSlide, {
          toValue: 0,
          duration: 420,
          useNativeDriver: true,
        }),
      ]),
      Animated.parallel([
        Animated.timing(formAnim, {
          toValue: 1,
          duration: 420,
          useNativeDriver: true,
        }),
        Animated.timing(formSlide, {
          toValue: 0,
          duration: 420,
          useNativeDriver: true,
        }),
      ]),
      Animated.parallel([
        Animated.timing(footerAnim, {
          toValue: 1,
          duration: 420,
          useNativeDriver: true,
        }),
        Animated.timing(footerSlide, {
          toValue: 0,
          duration: 420,
          useNativeDriver: true,
        }),
      ]),
    ]).start()
  }, [])

  // ── Google OAuth ──────────────────────────────────────────────────────────
  //
  // HOW EXPO GO GOOGLE AUTH WORKS:
  // expo-auth-session uses auth.expo.io as a proxy between your app and Google.
  // The redirect URI that Google receives is: https://auth.expo.io/@YOUR_USERNAME/readin
  // This proxy is what makes Google OAuth work without a production build.
  //
  // DEBUGGING: The console.log below prints your exact redirect URI.
  // Run the app, open Metro terminal, and copy the exact URL that prints.
  // Then add it to Google Cloud Console -> Credentials -> Web Client ->
  // Authorized redirect URIs.
  //
  // Also add to Authorized JavaScript origins: https://auth.expo.io
  //
  if (__DEV__) {
    const debugUri = AuthSession.makeRedirectUri({
      scheme: 'readin',
      path: '/(auth)/login',
    })
    console.log('══════════════════════════════════════════════')
    console.log('[Google Auth] Your redirect URI is:')
    console.log(debugUri)
    console.log('Add this EXACTLY to Google Cloud Console:')
    console.log('Credentials → Web Client → Authorized redirect URIs')
    console.log('══════════════════════════════════════════════')
  }

  const [, googleResponse, googlePromptAsync] = Google.useAuthRequest({
    clientId: process.env.EXPO_PUBLIC_GOOGLE_CLIENT_ID!,
    iosClientId: process.env.EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID,
    androidClientId: process.env.EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID,
    scopes: ['openid', 'profile', 'email'],
  })

  useEffect(() => {
    if (googleResponse?.type === 'success') {
      const token = googleResponse.authentication?.accessToken
      if (token) void handleGoogleSuccess(token)
    } else if (googleResponse?.type === 'error') {
      console.error('[Google Auth] Error response:', googleResponse.error)
      setErrors({
        general: `Google sign-in error: ${googleResponse.error?.message ?? 'Unknown error'}`,
      })
    }
  }, [googleResponse])

  const handleGoogleSuccess = async (accessToken: string) => {
    setIsGoogleLoading(true)
    try {
      // Fetch user info from Google
      const res = await fetch('https://www.googleapis.com/userinfo/v2/me', {
        headers: { Authorization: `Bearer ${accessToken}` },
      })

      if (!res.ok) {
        throw new Error(`Google userinfo failed: ${res.status}`)
      }

      const info = (await res.json()) as {
        id: string
        email: string
        name: string
        picture: string
      }

      // Send to our backend
      const response = await api.post('/auth/google', {
        googleId: info.id,
        email: info.email,
        displayName: info.name,
        avatar: info.picture,
      })

      const {
        accessToken: appToken,
        refreshToken,
        user,
      } = response.data.data as {
        accessToken: string
        refreshToken: string
        user: User
      }

      await login(user, appToken, refreshToken)
      router.replace('/(tabs)')
    } catch (err) {
      console.error('[Google Auth] Sign-in failed:', err)
      setErrors({
        general:
          'Google sign-in failed. Please try again or use email/password.',
      })
    } finally {
      setIsGoogleLoading(false)
    }
  }

  // ── Email login ───────────────────────────────────────────────────────────
  const handleLogin = async () => {
    const validationErrors = validate(form)
    if (Object.keys(validationErrors).length > 0) {
      setErrors(validationErrors)
      return
    }
    setErrors({})
    setIsLoading(true)

    try {
      const response = await api.post('/auth/login', {
        email: form.email.toLowerCase().trim(),
        password: form.password,
      })

      const { accessToken, refreshToken, user } = response.data.data as {
        accessToken: string
        refreshToken: string
        user: User
      }

      await login(user, accessToken, refreshToken)
      router.replace('/(tabs)')
    } catch (error: unknown) {
      if (typeof error === 'object' && error !== null && 'response' in error) {
        const e = error as {
          response?: { status?: number; data?: { message?: string } }
        }

        if (e.response?.status === 403) {
          setErrors({
            general:
              e.response.data?.message ??
              'Please verify your email before logging in. Check your inbox.',
          })
        } else if (e.response?.status === 401) {
          setErrors({ general: 'Incorrect email or password.' })
        } else if (e.response?.status === 429) {
          setErrors({
            general: 'Too many login attempts. Please wait a few minutes.',
          })
        } else {
          setErrors({ general: 'Something went wrong. Please try again.' })
        }
      } else {
        setErrors({
          general: 'Network error. Check your internet connection.',
        })
      }
    } finally {
      setIsLoading(false)
    }
  }

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: THEME.colors.background }}>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <ScrollView
          style={{ flex: 1 }}
          contentContainerStyle={{ flexGrow: 1 }}
          keyboardShouldPersistTaps='handled'
          showsVerticalScrollIndicator={false}
        >
          <View
            style={{
              flex: 1,
              paddingHorizontal: 24,
              paddingTop: 48,
              paddingBottom: 40,
              justifyContent: 'center',
              gap: 32,
            }}
          >
            {/* ── Section 1: Header ──────────────────────────────────────── */}
            <Animated.View
              style={{
                opacity: headerAnim,
                transform: [{ translateY: headerSlide }],
                gap: 8,
              }}
            >
              <Text
                style={{
                  fontSize: 36,
                  fontFamily: 'Inter_700Bold',
                  color: THEME.colors.text.primary,
                }}
              >
                {'Welcome back'}
              </Text>
              <Text
                style={{
                  fontSize: 16,
                  fontFamily: 'Inter_400Regular',
                  color: THEME.colors.text.secondary,
                }}
              >
                {'Sign in to continue reading'}
              </Text>
            </Animated.View>

            {/* ── Section 2: Form ────────────────────────────────────────── */}
            <Animated.View
              style={{
                opacity: formAnim,
                transform: [{ translateY: formSlide }],
                gap: 16,
              }}
            >
              {/* General error banner */}
              {errors.general !== undefined && (
                <View
                  style={{
                    backgroundColor: THEME.colors.error[500] + '18',
                    borderWidth: 1,
                    borderColor: THEME.colors.error[500] + '40',
                    borderRadius: 10,
                    paddingHorizontal: 16,
                    paddingVertical: 12,
                  }}
                >
                  <Text
                    style={{
                      color: THEME.colors.error[400],
                      fontSize: 14,
                      fontFamily: 'Inter_400Regular',
                      lineHeight: 20,
                    }}
                  >
                    {errors.general}
                  </Text>
                </View>
              )}

              <Input
                label='Email'
                placeholder='you@example.com'
                value={form.email}
                onChangeText={(t) => setForm((f) => ({ ...f, email: t }))}
                keyboardType='email-address'
                autoCapitalize='none'
                autoCorrect={false}
                autoComplete='email'
                leftIcon='mail-outline'
                error={errors.email}
              />

              <Input
                label='Password'
                placeholder='••••••••'
                value={form.password}
                onChangeText={(t) => setForm((f) => ({ ...f, password: t }))}
                secureTextEntry
                leftIcon='lock-closed-outline'
                error={errors.password}
              />

              <TouchableOpacity
                onPress={() => router.push('/(auth)/forgot-password')}
                style={{ alignSelf: 'flex-end' }}
                hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
              >
                <Text
                  style={{
                    color: THEME.colors.primary[500],
                    fontSize: 14,
                    fontFamily: 'Inter_500Medium',
                  }}
                >
                  {'Forgot password?'}
                </Text>
              </TouchableOpacity>
            </Animated.View>

            {/* ── Section 3: Buttons ─────────────────────────────────────── */}
            <Animated.View
              style={{
                opacity: footerAnim,
                transform: [{ translateY: footerSlide }],
                gap: 16,
              }}
            >
              {/* Sign in button */}
              <Button
                label='Sign In'
                variant='primary'
                size='lg'
                loading={isLoading}
                onPress={() => void handleLogin()}
              />

              {/* Divider */}
              <View
                style={{
                  flexDirection: 'row',
                  alignItems: 'center',
                  gap: 12,
                }}
              >
                <View
                  style={{
                    flex: 1,
                    height: 1,
                    backgroundColor: THEME.colors.border.default,
                  }}
                />
                <Text
                  style={{
                    fontFamily: 'Inter_400Regular',
                    fontSize: 12,
                    color: THEME.colors.text.muted,
                  }}
                >
                  {'or continue with'}
                </Text>
                <View
                  style={{
                    flex: 1,
                    height: 1,
                    backgroundColor: THEME.colors.border.default,
                  }}
                />
              </View>

              {/* Google button */}
              <TouchableOpacity
                activeOpacity={0.8}
                disabled={isGoogleLoading}
                onPress={() => void googlePromptAsync()}
                style={{
                  flexDirection: 'row',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 12,
                  backgroundColor: THEME.colors.surface,
                  borderWidth: 1,
                  borderColor: THEME.colors.border.default,
                  borderRadius: 12,
                  paddingVertical: 16,
                  opacity: isGoogleLoading ? 0.65 : 1,
                }}
              >
                <Ionicons
                  name='logo-google'
                  size={20}
                  color={THEME.colors.text.primary}
                />
                <Text
                  style={{
                    fontFamily: 'Inter_600SemiBold',
                    fontSize: 16,
                    color: THEME.colors.text.primary,
                  }}
                >
                  {isGoogleLoading ? 'Signing in...' : 'Continue with Google'}
                </Text>
              </TouchableOpacity>

              {/* Register link */}
              <View
                style={{
                  flexDirection: 'row',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 4,
                }}
              >
                <Text
                  style={{
                    fontFamily: 'Inter_400Regular',
                    fontSize: 14,
                    color: THEME.colors.text.secondary,
                  }}
                >
                  {"Don't have an account?"}
                </Text>
                <TouchableOpacity
                  onPress={() => router.push('/(auth)/register')}
                  hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                >
                  <Text
                    style={{
                      fontFamily: 'Inter_600SemiBold',
                      fontSize: 14,
                      color: THEME.colors.primary[500],
                    }}
                  >
                    {'Sign up'}
                  </Text>
                </TouchableOpacity>
              </View>
            </Animated.View>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  )
}
