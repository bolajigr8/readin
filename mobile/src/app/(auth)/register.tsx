import React, { useState } from 'react'
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
} from 'react-native'
import { router } from 'expo-router'
import { SafeAreaView } from 'react-native-safe-area-context'

import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import api from '@/services/api'

// ── Types ─────────────────────────────────────────────────────────────────────

interface FormState {
  displayName: string
  email: string
  password: string
  confirmPassword: string
}

interface FormErrors {
  displayName?: string
  email?: string
  password?: string
  confirmPassword?: string
  general?: string
}

// ── Validation ────────────────────────────────────────────────────────────────

const validate = (form: FormState): FormErrors => {
  const errors: FormErrors = {}
  if (!form.displayName.trim()) errors.displayName = 'Name is required'
  if (!form.email.trim()) errors.email = 'Email is required'
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email))
    errors.email = 'Enter a valid email'
  if (!form.password) errors.password = 'Password is required'
  else if (form.password.length < 8)
    errors.password = 'Password must be at least 8 characters'
  if (!form.confirmPassword)
    errors.confirmPassword = 'Please confirm your password'
  else if (form.password !== form.confirmPassword)
    errors.confirmPassword = 'Passwords do not match'
  return errors
}

// ── Screen ────────────────────────────────────────────────────────────────────

export default function RegisterScreen() {
  const [form, setForm] = useState<FormState>({
    displayName: '',
    email: '',
    password: '',
    confirmPassword: '',
  })
  const [errors, setErrors] = useState<FormErrors>({})
  const [isLoading, setIsLoading] = useState(false)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)

  const handleRegister = async () => {
    const validationErrors = validate(form)
    if (Object.keys(validationErrors).length > 0) {
      setErrors(validationErrors)
      return
    }

    setErrors({})
    setIsLoading(true)

    try {
      await api.post('/auth/register', {
        displayName: form.displayName.trim(),
        email: form.email.toLowerCase().trim(),
        password: form.password,
      })

      setSuccessMessage(
        'Account created! Check your email to verify your account before logging in.',
      )
    } catch (error: unknown) {
      if (typeof error === 'object' && error !== null && 'response' in error) {
        const axiosError = error as {
          response?: { status?: number; data?: { message?: string } }
        }
        const status = axiosError.response?.status

        if (status === 409) {
          setErrors({ email: 'An account with this email already exists.' })
        } else {
          setErrors({
            general:
              axiosError.response?.data?.message ??
              'Registration failed. Please try again.',
          })
        }
      } else {
        setErrors({ general: 'Network error. Check your connection.' })
      }
    } finally {
      setIsLoading(false)
    }
  }

  // ── Success state ───────────────────────────────────────────────────────────

  if (successMessage) {
    return (
      <SafeAreaView className='flex-1 bg-background px-6 justify-center items-center gap-6'>
        <View className='w-16 h-16 rounded-full bg-success-500/20 items-center justify-center'>
          <Text className='text-4xl'>📬</Text>
        </View>
        <View className='gap-2 items-center'>
          <Text className='text-2xl font-sans-bold text-content-primary text-center'>
            Check your inbox
          </Text>
          <Text className='text-content-secondary font-sans text-base text-center leading-6'>
            {successMessage}
          </Text>
        </View>
        <Button
          label='Back to Sign In'
          variant='primary'
          size='lg'
          onPress={() => router.replace('/(auth)/login')}
          className='w-full'
        />
      </SafeAreaView>
    )
  }

  // ── Form ────────────────────────────────────────────────────────────────────

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
          showsVerticalScrollIndicator={false}
        >
          <View className='flex-1 px-6 pt-12 pb-8 justify-center gap-8'>
            {/* Back button */}
            <TouchableOpacity
              onPress={() => router.back()}
              className='flex-row items-center gap-2 self-start'
            >
              <Text className='text-content-secondary font-sans text-sm'>
                ← Back
              </Text>
            </TouchableOpacity>

            {/* Header */}
            <View className='gap-2'>
              <Text className='text-4xl font-sans-bold text-content-primary'>
                Create account
              </Text>
              <Text className='text-content-secondary font-sans text-base'>
                Start your reading journey
              </Text>
            </View>

            {/* General error */}
            {errors.general && (
              <View className='bg-error-500/10 border border-error-500/30 rounded-md px-4 py-3'>
                <Text className='text-error-400 text-sm font-sans'>
                  {errors.general}
                </Text>
              </View>
            )}

            {/* Form */}
            <View className='gap-4'>
              <Input
                label='Display Name'
                placeholder='Your name'
                value={form.displayName}
                onChangeText={(t) => setForm((f) => ({ ...f, displayName: t }))}
                leftIcon='person-outline'
                error={errors.displayName}
                autoComplete='name'
              />
              <Input
                label='Email'
                placeholder='you@example.com'
                value={form.email}
                onChangeText={(t) => setForm((f) => ({ ...f, email: t }))}
                keyboardType='email-address'
                leftIcon='mail-outline'
                error={errors.email}
                autoComplete='email'
              />
              <Input
                label='Password'
                placeholder='Min. 8 characters'
                value={form.password}
                onChangeText={(t) => setForm((f) => ({ ...f, password: t }))}
                secureTextEntry
                leftIcon='lock-closed-outline'
                error={errors.password}
              />
              <Input
                label='Confirm Password'
                placeholder='Repeat your password'
                value={form.confirmPassword}
                onChangeText={(t) =>
                  setForm((f) => ({ ...f, confirmPassword: t }))
                }
                secureTextEntry
                leftIcon='lock-closed-outline'
                error={errors.confirmPassword}
              />
            </View>

            {/* Submit */}
            <Button
              label='Create Account'
              variant='primary'
              size='lg'
              loading={isLoading}
              onPress={handleRegister}
              className='w-full'
            />

            {/* Login link */}
            <View className='flex-row justify-center gap-1'>
              <Text className='text-content-secondary font-sans text-sm'>
                Already have an account?
              </Text>
              <TouchableOpacity onPress={() => router.push('/(auth)/login')}>
                <Text className='text-primary-500 font-sans-semibold text-sm'>
                  Sign in
                </Text>
              </TouchableOpacity>
            </View>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  )
}
