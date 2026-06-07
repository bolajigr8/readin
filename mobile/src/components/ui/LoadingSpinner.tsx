import React from 'react'
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native'
import { THEME } from '@/constants/theme'

interface LoadingSpinnerProps {
  fullScreen?: boolean
  label?: string
  size?: 'small' | 'large'
}

export function LoadingSpinner({
  fullScreen = false,
  label,
  size = 'large',
}: LoadingSpinnerProps) {
  if (fullScreen) {
    return (
      <View style={styles.fullScreen}>
        <ActivityIndicator size={size} color={THEME.colors.primary[500]} />
        {label !== undefined && <Text style={styles.label}>{label}</Text>}
      </View>
    )
  }

  return (
    <View style={styles.inline}>
      <ActivityIndicator size={size} color={THEME.colors.primary[500]} />
      {label !== undefined && <Text style={styles.label}>{label}</Text>}
    </View>
  )
}

const styles = StyleSheet.create({
  fullScreen: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: THEME.colors.background,
    gap: 12,
  },
  inline: {
    alignItems: 'center',
    justifyContent: 'center',
    flex: 1,
    gap: 12,
  },
  label: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    color: THEME.colors.text.secondary,
  },
})
