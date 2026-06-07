import React from 'react'
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native'
import { Ionicons } from '@expo/vector-icons'
import { router } from 'expo-router'
import { THEME } from '@/constants/theme'

interface PremiumBannerProps {
  message: string
  onDismiss?: () => void
}

export const PremiumBanner = React.memo(function PremiumBanner({
  message,
  onDismiss,
}: PremiumBannerProps) {
  return (
    <View style={styles.banner}>
      <View style={styles.iconWrap}>
        <Ionicons name='star' size={14} color={THEME.colors.amber[400]} />
      </View>
      <Text style={styles.message} numberOfLines={2}>
        {message}
      </Text>
      <TouchableOpacity
        style={styles.upgradeBtn}
        onPress={() => router.push('/upgrade' as any)}
        activeOpacity={0.85}
      >
        <Text style={styles.upgradeBtnText}>Upgrade</Text>
      </TouchableOpacity>
      {onDismiss !== undefined && (
        <TouchableOpacity
          onPress={onDismiss}
          hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
        >
          <Ionicons name='close' size={14} color={THEME.colors.text.muted} />
        </TouchableOpacity>
      )}
    </View>
  )
})

const styles = StyleSheet.create({
  banner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: THEME.colors.amber[400] + '12',
    borderWidth: 1,
    borderColor: THEME.colors.amber[400] + '35',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 8,
  },
  iconWrap: {
    width: 26,
    height: 26,
    borderRadius: 13,
    backgroundColor: THEME.colors.amber[400] + '20',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  message: {
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.secondary,
    lineHeight: 18,
  },
  upgradeBtn: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 6,
    backgroundColor: THEME.colors.amber[400],
    flexShrink: 0,
  },
  upgradeBtnText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 12,
    color: '#000000',
  },
})
