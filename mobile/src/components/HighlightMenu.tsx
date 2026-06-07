import React, { useEffect, useRef } from 'react'
import {
  Animated,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native'
import { Ionicons } from '@expo/vector-icons'
import { THEME } from '@/constants/theme'
import type { HighlightColor } from '@/hooks/useAnnotations'

interface HighlightMenuProps {
  isVisible: boolean
  selectedText: string
  onHighlight: (color: HighlightColor) => void
  onAddNote: () => void
  onDismiss: () => void
}

const COLORS: { key: HighlightColor; hex: string; label: string }[] = [
  { key: 'yellow', hex: '#FDE68A', label: 'Yellow' },
  { key: 'green', hex: '#6EE7B7', label: 'Green' },
  { key: 'blue', hex: '#93C5FD', label: 'Blue' },
  { key: 'pink', hex: '#F9A8D4', label: 'Pink' },
  { key: 'purple', hex: '#C4B5FD', label: 'Purple' },
]

export function HighlightMenu({
  isVisible,
  selectedText,
  onHighlight,
  onAddNote,
  onDismiss,
}: HighlightMenuProps) {
  const slideAnim = useRef(new Animated.Value(120)).current
  const opacityAnim = useRef(new Animated.Value(0)).current
  const [mounted, setMounted] = React.useState(false)

  useEffect(() => {
    if (isVisible) {
      setMounted(true)
      Animated.parallel([
        Animated.spring(slideAnim, {
          toValue: 0,
          friction: 9,
          tension: 120,
          useNativeDriver: true,
        }),
        Animated.timing(opacityAnim, {
          toValue: 1,
          duration: 200,
          useNativeDriver: true,
        }),
      ]).start()
    } else {
      Animated.parallel([
        Animated.timing(slideAnim, {
          toValue: 120,
          duration: 200,
          useNativeDriver: true,
        }),
        Animated.timing(opacityAnim, {
          toValue: 0,
          duration: 150,
          useNativeDriver: true,
        }),
      ]).start(() => setMounted(false))
    }
  }, [isVisible, slideAnim, opacityAnim])

  if (!mounted) return null

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents='box-none'>
      {/* Tap outside to dismiss */}
      <TouchableOpacity
        style={StyleSheet.absoluteFill}
        activeOpacity={1}
        onPress={onDismiss}
      />

      <Animated.View
        style={[
          styles.menu,
          {
            transform: [{ translateY: slideAnim }],
            opacity: opacityAnim,
          },
        ]}
      >
        {/* Selected text preview */}
        {selectedText.length > 0 && (
          <Text style={styles.preview} numberOfLines={2}>
            "
            {selectedText.length > 80
              ? selectedText.slice(0, 80) + '...'
              : selectedText}
            "
          </Text>
        )}

        <View style={styles.row}>
          {/* Color swatches */}
          <View style={styles.colors}>
            {COLORS.map((c) => (
              <TouchableOpacity
                key={c.key}
                onPress={() => onHighlight(c.key)}
                style={[styles.colorSwatch, { backgroundColor: c.hex }]}
                activeOpacity={0.8}
                accessibilityLabel={`Highlight ${c.label}`}
              />
            ))}
          </View>

          {/* Divider */}
          <View style={styles.divider} />

          {/* Add note */}
          <TouchableOpacity
            onPress={onAddNote}
            style={styles.noteBtn}
            activeOpacity={0.8}
          >
            <Ionicons
              name='create-outline'
              size={18}
              color={THEME.colors.primary[500]}
            />
            <Text style={styles.noteBtnText}>Note</Text>
          </TouchableOpacity>

          {/* Dismiss */}
          <TouchableOpacity
            onPress={onDismiss}
            style={styles.closeBtn}
            hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
          >
            <Ionicons name='close' size={18} color={THEME.colors.text.muted} />
          </TouchableOpacity>
        </View>
      </Animated.View>
    </View>
  )
}

const styles = StyleSheet.create({
  menu: {
    position: 'absolute',
    bottom: 80, // above the reader bottom toolbar
    left: 16,
    right: 16,
    backgroundColor: THEME.colors.elevated,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: THEME.colors.border.light,
    padding: 16,
    gap: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.4,
    shadowRadius: 16,
    elevation: 12,
  },
  preview: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.secondary,
    fontStyle: 'italic',
    lineHeight: 18,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  colors: {
    flexDirection: 'row',
    gap: 10,
    flex: 1,
  },
  colorSwatch: {
    width: 28,
    height: 28,
    borderRadius: 14,
    borderWidth: 2,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  divider: {
    width: 1,
    height: 28,
    backgroundColor: THEME.colors.border.default,
  },
  noteBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 8,
    backgroundColor: THEME.colors.primary[500] + '18',
    borderWidth: 1,
    borderColor: THEME.colors.primary[500] + '40',
  },
  noteBtnText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    color: THEME.colors.primary[500],
  },
  closeBtn: {
    width: 28,
    height: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
})
