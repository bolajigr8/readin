import React from 'react'
import { View, Text, StyleSheet } from 'react-native'
import { Ionicons } from '@expo/vector-icons'
import { Button } from '@/components/ui/Button'
import { THEME } from '@/constants/theme'

type IoniconsName = keyof typeof Ionicons.glyphMap

interface EmptyStateProps {
  icon: IoniconsName
  title: string
  description: string
  actionLabel?: string
  onAction?: () => void
}

export const EmptyState = React.memo(function EmptyState({
  icon,
  title,
  description,
  actionLabel,
  onAction,
}: EmptyStateProps) {
  return (
    <View style={styles.container}>
      {/* Icon in a styled circle */}
      <View style={styles.iconRing}>
        <View style={styles.iconInner}>
          <Ionicons name={icon} size={40} color={THEME.colors.text.muted} />
        </View>
      </View>

      <Text style={styles.title}>{title}</Text>
      <Text style={styles.description}>{description}</Text>

      {actionLabel !== undefined && onAction !== undefined && (
        <Button
          label={actionLabel}
          variant='outline'
          size='md'
          onPress={onAction}
        />
      )}
    </View>
  )
})

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 40,
    gap: 16,
    minHeight: 300,
  },
  iconRing: {
    width: 96,
    height: 96,
    borderRadius: 48,
    backgroundColor: THEME.colors.surface,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 8,
  },
  iconInner: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: THEME.colors.elevated,
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 20,
    color: THEME.colors.text.primary,
    textAlign: 'center',
  },
  description: {
    fontFamily: 'Inter_400Regular',
    fontSize: 15,
    color: THEME.colors.text.secondary,
    textAlign: 'center',
    lineHeight: 23,
  },
})
