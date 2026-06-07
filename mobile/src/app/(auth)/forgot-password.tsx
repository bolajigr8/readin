import React, { useState } from 'react'
import {
  View,
  Text,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  TouchableOpacity,
} from 'react-native'
import { router } from 'expo-router'
import { SafeAreaView } from 'react-native-safe-area-context'

import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import api from '@/services/api'

export default function ForgotPasswordScreen() {
  const [email, setEmail] = useState('')
  const [emailError, setEmailError] = useState<string | undefined>()
  const [isLoading, setIsLoading] = useState(false)
  const [submitted, setSubmitted] = useState(false)

  const handleSubmit = async () => {
    if (!email.trim()) {
      setEmailError('Email is required')
      return
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setEmailError('Enter a valid email address')
      return
    }

    setEmailError(undefined)
    setIsLoading(true)

    try {
      await api.post('/auth/forgot-password', {
        email: email.toLowerCase().trim(),
      })
      // Always show success — server never reveals if email exists
      setSubmitted(true)
    } catch {
      // Still show success to avoid email enumeration
      setSubmitted(true)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <SafeAreaView className='flex-1 bg-background'>
      <KeyboardAvoidingView
        className='flex-1'
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <ScrollView
          className='flex-1'
          contentContainerStyle={{ flexGrow: 1 }}
          keyboardShouldPersistTaps='handled'
        >
          <View className='flex-1 px-6 pt-12 pb-8 justify-center gap-8'>
            {/* Back */}
            <TouchableOpacity
              onPress={() => router.back()}
              className='self-start'
            >
              <Text className='text-content-secondary font-sans text-sm'>
                ← Back
              </Text>
            </TouchableOpacity>

            {submitted ? (
              // ── Success state ───────────────────────────────────────
              <View className='gap-6 items-center'>
                <View className='w-16 h-16 rounded-full bg-primary-500/20 items-center justify-center'>
                  <Text className='text-4xl'>✉️</Text>
                </View>
                <View className='gap-2 items-center'>
                  <Text className='text-2xl font-sans-bold text-content-primary text-center'>
                    Email sent
                  </Text>
                  <Text className='text-content-secondary font-sans text-base text-center leading-6'>
                    If an account with that email exists, we've sent a reset
                    link. Check your inbox and spam folder.
                  </Text>
                </View>
                <Button
                  label='Back to Sign In'
                  variant='outline'
                  size='lg'
                  onPress={() => router.replace('/(auth)/login')}
                  className='w-full'
                />
              </View>
            ) : (
              // ── Form ────────────────────────────────────────────────
              <>
                <View className='gap-2'>
                  <Text className='text-4xl font-sans-bold text-content-primary'>
                    Reset password
                  </Text>
                  <Text className='text-content-secondary font-sans text-base'>
                    Enter your email and we'll send a reset link
                  </Text>
                </View>

                <Input
                  label='Email'
                  placeholder='you@example.com'
                  value={email}
                  onChangeText={setEmail}
                  keyboardType='email-address'
                  leftIcon='mail-outline'
                  error={emailError}
                  autoComplete='email'
                />

                <Button
                  label='Send Reset Link'
                  variant='primary'
                  size='lg'
                  loading={isLoading}
                  onPress={handleSubmit}
                  className='w-full'
                />
              </>
            )}
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  )
}
