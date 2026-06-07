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
import { router } from 'expo-router'
import { THEME } from '@/constants/theme'

interface ReaderToolbarProps {
  title: string
  currentChapter: number
  totalChapters: number
  percentage: number
  isVisible: boolean
  bookId: string
  onChaptersPress: () => void
  onSettingsPress: () => void
  onAnnotationsPress: () => void
  onNextChapter: () => void
  onPrevChapter: () => void
}

export function ReaderToolbar({
  title,
  currentChapter,
  totalChapters,
  percentage,
  isVisible,
  onChaptersPress,
  onSettingsPress,
  onAnnotationsPress,
  onNextChapter,
  onPrevChapter,
}: ReaderToolbarProps) {
  const insets = useSafeAreaInsets()
  const anim = useRef(new Animated.Value(1)).current

  useEffect(() => {
    Animated.timing(anim, {
      toValue: isVisible ? 1 : 0,
      duration: 200,
      useNativeDriver: true,
    }).start()
  }, [isVisible, anim])

  return (
    <Animated.View
      style={[styles.container, { opacity: anim }]}
      pointerEvents={isVisible ? 'box-none' : 'none'}
    >
      {/* Top bar */}
      <View
        style={[
          styles.topBar,
          { paddingTop: insets.top + 8, height: insets.top + 56 },
        ]}
      >
        {/* Back */}
        <TouchableOpacity
          onPress={() => router.back()}
          style={styles.iconBtn}
          hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
        >
          <Ionicons
            name='arrow-back'
            size={22}
            color={THEME.colors.text.primary}
          />
        </TouchableOpacity>

        {/* Title */}
        <Text style={styles.barTitle} numberOfLines={1}>
          {title}
        </Text>

        {/* Right actions */}
        <View style={styles.rightActions}>
          <TouchableOpacity
            onPress={onAnnotationsPress}
            style={styles.iconBtn}
            hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
          >
            <Ionicons
              name='bookmark-outline'
              size={22}
              color={THEME.colors.text.primary}
            />
          </TouchableOpacity>
          <TouchableOpacity
            onPress={onChaptersPress}
            style={styles.iconBtn}
            hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
          >
            <Ionicons
              name='list-outline'
              size={22}
              color={THEME.colors.text.primary}
            />
          </TouchableOpacity>
          <TouchableOpacity
            onPress={onSettingsPress}
            style={styles.iconBtn}
            hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
          >
            <Ionicons
              name='settings-outline'
              size={22}
              color={THEME.colors.text.primary}
            />
          </TouchableOpacity>
        </View>
      </View>

      {/* Bottom bar */}
      <View style={[styles.bottomBar, { paddingBottom: insets.bottom + 8 }]}>
        {/* Prev chapter */}
        <TouchableOpacity
          onPress={onPrevChapter}
          style={styles.iconBtn}
          hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
        >
          <Ionicons
            name='chevron-back'
            size={22}
            color={
              totalChapters === 0
                ? THEME.colors.text.muted
                : THEME.colors.text.primary
            }
          />
        </TouchableOpacity>

        {/* Chapter info */}
        <View style={styles.chapterInfo}>
          <Text style={styles.chapterText} numberOfLines={1}>
            {totalChapters > 0
              ? `Chapter ${currentChapter + 1} of ${totalChapters}`
              : 'Reading...'}
          </Text>
          <Text style={styles.percentageText}>{`${percentage}%`}</Text>
        </View>

        {/* Next chapter */}
        <TouchableOpacity
          onPress={onNextChapter}
          style={styles.iconBtn}
          hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
        >
          <Ionicons
            name='chevron-forward'
            size={22}
            color={
              totalChapters === 0
                ? THEME.colors.text.muted
                : THEME.colors.text.primary
            }
          />
        </TouchableOpacity>
      </View>
    </Animated.View>
  )
}

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'space-between',
    pointerEvents: 'box-none',
  },
  topBar: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    paddingHorizontal: 16,
    paddingBottom: 12,
    backgroundColor: 'rgba(10,10,10,0.88)',
    borderBottomWidth: 1,
    borderBottomColor: THEME.colors.border.default,
    gap: 8,
  },
  iconBtn: {
    width: 36,
    height: 36,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 8,
    backgroundColor: THEME.colors.surface + 'CC',
    flexShrink: 0,
  },
  barTitle: {
    flex: 1,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 15,
    color: THEME.colors.text.primary,
    textAlign: 'center',
  },
  rightActions: {
    flexDirection: 'row',
    gap: 6,
  },
  bottomBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 12,
    backgroundColor: 'rgba(10,10,10,0.88)',
    borderTopWidth: 1,
    borderTopColor: THEME.colors.border.default,
    gap: 16,
  },
  chapterInfo: {
    flex: 1,
    alignItems: 'center',
    gap: 2,
  },
  chapterText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.secondary,
  },
  percentageText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 14,
    color: THEME.colors.primary[500],
  },
})
