import React, { useEffect, useRef } from 'react'
import {
  Animated,
  Dimensions,
  FlatList,
  StyleSheet,
  Text,
  TouchableOpacity,
  TouchableWithoutFeedback,
  View,
} from 'react-native'
import { useSafeAreaInsets } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { THEME } from '@/constants/theme'
import type { TocItem } from '@/store/readerStore'

interface ChapterDrawerProps {
  toc: TocItem[]
  currentChapter: number
  isOpen: boolean
  onClose: () => void
  onChapterSelect: (cfi: string) => void
}

const DRAWER_WIDTH = Math.min(Dimensions.get('window').width * 0.78, 300)
const SPRING = { friction: 9, tension: 120, useNativeDriver: true }

function renderTocItem(
  item: TocItem,
  depth: number,
  currentChapter: number,
  index: number,
  onSelect: (cfi: string) => void,
): React.ReactElement {
  const isActive = index === currentChapter
  return (
    <View key={item.id ?? item.href}>
      <TouchableOpacity
        onPress={() => onSelect(item.href)}
        activeOpacity={0.7}
        style={[
          styles.tocItem,
          { paddingLeft: 20 + depth * 16 },
          isActive && styles.tocItemActive,
        ]}
      >
        {isActive && (
          <View
            style={[
              styles.tocActiveBar,
              { backgroundColor: THEME.colors.primary[500] },
            ]}
          />
        )}
        <Text
          style={[
            styles.tocLabel,
            { fontFamily: isActive ? 'Inter_600SemiBold' : 'Inter_400Regular' },
            {
              color: isActive
                ? THEME.colors.primary[500]
                : THEME.colors.text.secondary,
            },
          ]}
          numberOfLines={2}
        >
          {item.label}
        </Text>
      </TouchableOpacity>
      {item.subitems?.map((sub, si) =>
        renderTocItem(sub, depth + 1, currentChapter, si, onSelect),
      )}
    </View>
  )
}

export function ChapterDrawer({
  toc,
  currentChapter,
  isOpen,
  onClose,
  onChapterSelect,
}: ChapterDrawerProps) {
  const insets = useSafeAreaInsets()
  const slideAnim = useRef(new Animated.Value(-DRAWER_WIDTH)).current
  const backdropAnim = useRef(new Animated.Value(0)).current
  const [mounted, setMounted] = React.useState(false)

  useEffect(() => {
    if (isOpen) {
      setMounted(true)
      Animated.parallel([
        Animated.spring(slideAnim, { toValue: 0, ...SPRING }),
        Animated.timing(backdropAnim, {
          toValue: 1,
          duration: 200,
          useNativeDriver: true,
        }),
      ]).start()
    } else {
      Animated.parallel([
        Animated.spring(slideAnim, { toValue: -DRAWER_WIDTH, ...SPRING }),
        Animated.timing(backdropAnim, {
          toValue: 0,
          duration: 180,
          useNativeDriver: true,
        }),
      ]).start(() => setMounted(false))
    }
  }, [isOpen, slideAnim, backdropAnim])

  if (!mounted) return null

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents='box-none'>
      {/* Backdrop */}
      <TouchableWithoutFeedback onPress={onClose}>
        <Animated.View
          style={[
            StyleSheet.absoluteFill,
            {
              backgroundColor: '#000',
              opacity: backdropAnim.interpolate({
                inputRange: [0, 1],
                outputRange: [0, 0.6],
              }),
            },
          ]}
        />
      </TouchableWithoutFeedback>

      {/* Drawer */}
      <Animated.View
        style={[
          styles.drawer,
          { width: DRAWER_WIDTH, transform: [{ translateX: slideAnim }] },
        ]}
      >
        {/* Header */}
        <View style={[styles.header, { paddingTop: insets.top + 12 }]}>
          <Text style={styles.headerTitle}>Table of Contents</Text>
          <TouchableOpacity
            onPress={onClose}
            style={styles.closeBtn}
            hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
          >
            <Ionicons
              name='close'
              size={20}
              color={THEME.colors.text.secondary}
            />
          </TouchableOpacity>
        </View>

        <View style={styles.divider} />

        {/* TOC list */}
        {toc.length === 0 ? (
          <View style={styles.emptyToc}>
            <Text style={styles.emptyTocText}>No chapters found</Text>
          </View>
        ) : (
          <FlatList
            data={toc}
            keyExtractor={(item, i) => item.id ?? String(i)}
            showsVerticalScrollIndicator={false}
            contentContainerStyle={{ paddingBottom: insets.bottom + 16 }}
            renderItem={({ item, index }) =>
              renderTocItem(item, 0, currentChapter, index, (cfi) => {
                onChapterSelect(cfi)
                onClose()
              })
            }
          />
        )}
      </Animated.View>
    </View>
  )
}

const styles = StyleSheet.create({
  drawer: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    backgroundColor: THEME.colors.surface,
    borderRightWidth: 1,
    borderRightColor: THEME.colors.border.default,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingBottom: 16,
  },
  headerTitle: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 16,
    color: THEME.colors.text.primary,
  },
  closeBtn: {
    width: 30,
    height: 30,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 8,
    backgroundColor: THEME.colors.elevated,
  },
  divider: {
    height: 1,
    backgroundColor: THEME.colors.border.default,
    marginHorizontal: 20,
  },
  tocItem: {
    paddingVertical: 13,
    paddingRight: 20,
    position: 'relative',
  },
  tocItemActive: {
    backgroundColor: THEME.colors.primary[500] + '10',
  },
  tocActiveBar: {
    position: 'absolute',
    left: 0,
    top: 8,
    bottom: 8,
    width: 3,
    borderTopRightRadius: 3,
    borderBottomRightRadius: 3,
  },
  tocLabel: {
    fontSize: 14,
    lineHeight: 20,
  },
  emptyToc: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyTocText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    color: THEME.colors.text.muted,
  },
})
