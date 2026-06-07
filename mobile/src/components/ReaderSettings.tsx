import React, { useEffect, useRef } from 'react'
import {
  Animated,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native'
import { useSafeAreaInsets } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { THEME } from '@/constants/theme'

// Theme is locked to dark — not configurable.
// The reader always uses dark mode to match the app's design system.
// epub.js theme injection via WebView messages is unreliable in Expo Go,
// and the app is built as a dark-first experience.

interface ReaderSettingsProps {
  isOpen: boolean
  onClose: () => void
  fontSize: number
  fontFamily: 'serif' | 'sans-serif'
  onFontSizeChange: (size: number) => void
  onFontFamilyChange: (family: 'serif' | 'sans-serif') => void
}

export function ReaderSettings({
  isOpen,
  onClose,
  fontSize,
  fontFamily,
  onFontSizeChange,
  onFontFamilyChange,
}: ReaderSettingsProps) {
  const insets = useSafeAreaInsets()
  const slideAnim = useRef(new Animated.Value(300)).current
  const [mounted, setMounted] = React.useState(false)

  useEffect(() => {
    if (isOpen) {
      setMounted(true)
      Animated.spring(slideAnim, {
        toValue: 0,
        friction: 9,
        tension: 120,
        useNativeDriver: true,
      }).start()
    } else {
      Animated.timing(slideAnim, {
        toValue: 300,
        duration: 200,
        useNativeDriver: true,
      }).start(() => setMounted(false))
    }
  }, [isOpen, slideAnim])

  if (!mounted) return null

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents='box-none'>
      {/* Tap outside to close */}
      <TouchableOpacity
        style={StyleSheet.absoluteFill}
        activeOpacity={1}
        onPress={onClose}
      />

      {/* Settings sheet */}
      <Animated.View
        style={[
          styles.sheet,
          {
            paddingBottom: insets.bottom + 16,
            transform: [{ translateY: slideAnim }],
          },
        ]}
      >
        {/* Handle */}
        <View style={styles.handle} />

        <Text style={styles.sheetTitle}>{'Reader Settings'}</Text>

        {/* Font size */}
        <View style={styles.row}>
          <View style={styles.rowLeft}>
            <View style={styles.iconWrap}>
              <Ionicons
                name='text-outline'
                size={16}
                color={THEME.colors.primary[500]}
              />
            </View>
            <Text style={styles.rowLabel}>{'Font Size'}</Text>
          </View>
          <View style={styles.sizeControl}>
            <TouchableOpacity
              onPress={() => onFontSizeChange(fontSize - 2)}
              disabled={fontSize <= 12}
              style={styles.sizeBtn}
              hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
            >
              <Ionicons
                name='remove-circle-outline'
                size={24}
                color={
                  fontSize <= 12
                    ? THEME.colors.text.muted
                    : THEME.colors.primary[500]
                }
              />
            </TouchableOpacity>
            <Text style={styles.sizeValue}>{fontSize}</Text>
            <TouchableOpacity
              onPress={() => onFontSizeChange(fontSize + 2)}
              disabled={fontSize >= 28}
              style={styles.sizeBtn}
              hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
            >
              <Ionicons
                name='add-circle-outline'
                size={24}
                color={
                  fontSize >= 28
                    ? THEME.colors.text.muted
                    : THEME.colors.primary[500]
                }
              />
            </TouchableOpacity>
          </View>
        </View>

        {/* Font family */}
        <View style={styles.row}>
          <View style={styles.rowLeft}>
            <View style={styles.iconWrap}>
              <Ionicons
                name='book-outline'
                size={16}
                color={THEME.colors.amber[400]}
              />
            </View>
            <Text style={styles.rowLabel}>{'Font Style'}</Text>
          </View>
          <View style={styles.toggleRow}>
            {(['sans-serif', 'serif'] as const).map((f) => (
              <TouchableOpacity
                key={f}
                onPress={() => onFontFamilyChange(f)}
                style={[
                  styles.toggleBtn,
                  fontFamily === f && styles.toggleBtnActive,
                ]}
              >
                <Text
                  style={[
                    styles.toggleLabel,
                    fontFamily === f && {
                      color: THEME.colors.primary[500],
                      fontFamily: 'Inter_600SemiBold',
                    },
                  ]}
                >
                  {f === 'serif' ? 'Serif' : 'Sans'}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* Dark mode info — not changeable */}
        <View style={styles.darkModeNote}>
          <Ionicons name='moon' size={14} color={THEME.colors.primary[500]} />
          <Text style={styles.darkModeText}>
            {'ReadIn uses dark mode for the best reading experience.'}
          </Text>
        </View>
      </Animated.View>
    </View>
  )
}

const styles = StyleSheet.create({
  sheet: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: THEME.colors.elevated,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    borderTopWidth: 1,
    borderTopColor: THEME.colors.border.light,
    paddingHorizontal: 24,
    paddingTop: 12,
    gap: 20,
  },
  handle: {
    width: 36,
    height: 4,
    backgroundColor: THEME.colors.border.light,
    borderRadius: 2,
    alignSelf: 'center',
    marginBottom: 4,
  },
  sheetTitle: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 16,
    color: THEME.colors.text.primary,
    textAlign: 'center',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 16,
  },
  rowLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  iconWrap: {
    width: 30,
    height: 30,
    borderRadius: 8,
    backgroundColor: THEME.colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
  },
  rowLabel: {
    fontFamily: 'Inter_500Medium',
    fontSize: 15,
    color: THEME.colors.text.primary,
  },
  sizeControl: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    backgroundColor: THEME.colors.surface,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  sizeBtn: {
    width: 30,
    height: 30,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sizeValue: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 17,
    color: THEME.colors.text.primary,
    minWidth: 28,
    textAlign: 'center',
  },
  toggleRow: {
    flexDirection: 'row',
    gap: 8,
  },
  toggleBtn: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    backgroundColor: THEME.colors.surface,
  },
  toggleBtnActive: {
    borderColor: THEME.colors.primary[500],
    backgroundColor: THEME.colors.primary[500] + '15',
  },
  toggleLabel: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    color: THEME.colors.text.secondary,
  },
  darkModeNote: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: THEME.colors.primary[500] + '10',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 4,
  },
  darkModeText: {
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: THEME.colors.text.secondary,
    lineHeight: 17,
  },
})
