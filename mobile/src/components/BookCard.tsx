import React, { useEffect, useRef } from 'react'
import {
  View,
  Text,
  TouchableOpacity,
  Image,
  Animated,
  StyleSheet,
} from 'react-native'
import { Ionicons } from '@expo/vector-icons'
import { THEME } from '@/constants/theme'
import { formatFileSize, getCoverColor, getTitleInitials } from '@/utils/format'
import type { Book } from '@/types'

// ── Size configuration ────────────────────────────────────────────────────────

const SIZE_CONFIG = {
  sm: {
    width: 120,
    coverHeight: 156,
    titleSize: 12,
    authorSize: 11,
    padding: 8,
    radius: 10,
  },
  md: {
    width: '100%' as const,
    coverHeight: 180,
    titleSize: 13,
    authorSize: 12,
    padding: 10,
    radius: 12,
  },
  lg: {
    width: '100%' as const,
    coverHeight: 220,
    titleSize: 15,
    authorSize: 13,
    padding: 12,
    radius: 14,
  },
} as const

type Size = keyof typeof SIZE_CONFIG

interface BookCardProps {
  book: Book
  size?: Size
  onPress: () => void
}

// ── Cover fallback ────────────────────────────────────────────────────────────

function CoverFallback({
  title,
  height,
  borderRadius,
}: {
  title: string
  height: number
  borderRadius: number
}) {
  const color = getCoverColor(title)
  const initials = getTitleInitials(title)

  return (
    <View
      style={[
        styles.coverFallback,
        {
          height,
          borderRadius,
          backgroundColor: color + '25',
          borderColor: color + '40',
        },
      ]}
    >
      {/* Decorative glow */}
      <View
        style={[
          styles.coverGlow,
          { backgroundColor: color + '30', borderRadius },
        ]}
      />
      <Text style={[styles.coverInitials, { color }]}>{initials}</Text>
      <Ionicons
        name='book-outline'
        size={20}
        color={color + '60'}
        style={{ marginTop: 6 }}
      />
    </View>
  )
}

// ── Converting badge ──────────────────────────────────────────────────────────

function ConvertingBadge() {
  const pulseAnim = useRef(new Animated.Value(1)).current

  useEffect(() => {
    const pulse = Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue: 0.3,
          duration: 700,
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue: 1,
          duration: 700,
          useNativeDriver: true,
        }),
      ]),
    )
    pulse.start()
    return () => pulse.stop()
  }, [pulseAnim])

  return (
    <View style={styles.convertingBadge}>
      <Animated.View style={[styles.convertingDot, { opacity: pulseAnim }]} />
      <Text style={styles.convertingText}>Converting</Text>
    </View>
  )
}

// ── Main BookCard ─────────────────────────────────────────────────────────────

const BookCardComponent = ({ book, size = 'md', onPress }: BookCardProps) => {
  const config = SIZE_CONFIG[size]
  const isConverting = book.status === 'converting' || book.status === 'queued'
  const hasCover = book.coverUrl.length > 0
  const hasProgress =
    book.progress !== null &&
    book.progress !== undefined &&
    book.progress.percentage > 0

  return (
    <TouchableOpacity
      activeOpacity={0.78}
      onPress={onPress}
      style={[
        styles.container,
        {
          width: config.width,
          borderRadius: config.radius,
          padding: config.padding,
        },
      ]}
    >
      {/* Cover image or fallback */}
      <View style={{ position: 'relative' }}>
        {hasCover ? (
          <Image
            source={{ uri: book.coverUrl }}
            style={[
              styles.cover,
              { height: config.coverHeight, borderRadius: config.radius - 2 },
            ]}
            resizeMode='cover'
          />
        ) : (
          <CoverFallback
            title={book.title}
            height={config.coverHeight}
            borderRadius={config.radius - 2}
          />
        )}

        {/* Converting overlay badge */}
        {isConverting && (
          <View style={styles.badgeOverlay}>
            <ConvertingBadge />
          </View>
        )}

        {/* Completed checkmark */}
        {book.progress?.isCompleted === true && (
          <View style={styles.completedBadge}>
            <Ionicons
              name='checkmark-circle'
              size={20}
              color={THEME.colors.success[500]}
            />
          </View>
        )}
      </View>

      {/* Text content */}
      <View style={styles.textArea}>
        <Text
          style={[styles.title, { fontSize: config.titleSize }]}
          numberOfLines={2}
        >
          {book.title}
        </Text>
        {book.author.length > 0 && (
          <Text
            style={[styles.author, { fontSize: config.authorSize }]}
            numberOfLines={1}
          >
            {book.author}
          </Text>
        )}

        {/* File size — only on small cards */}
        {size === 'sm' && book.fileSize > 0 && (
          <Text style={styles.meta}>{formatFileSize(book.fileSize)}</Text>
        )}
      </View>

      {/* Reading progress bar */}
      {hasProgress && book.progress !== null && book.progress !== undefined && (
        <View style={styles.progressTrack}>
          <View
            style={[
              styles.progressFill,
              { width: `${book.progress.percentage}%` },
            ]}
          />
        </View>
      )}
    </TouchableOpacity>
  )
}

// Only re-render if book._id, book.status, book.progress, or size changes
export const BookCard = React.memo(
  BookCardComponent,
  (prev, next) =>
    prev.book._id === next.book._id &&
    prev.book.status === next.book.status &&
    prev.book.progress?.percentage === next.book.progress?.percentage &&
    prev.size === next.size,
)

// ── Styles ────────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    backgroundColor: THEME.colors.surface,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    gap: 8,
  },
  cover: {
    width: '100%',
  },
  coverFallback: {
    width: '100%',
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 0,
  },
  coverGlow: {
    position: 'absolute',
    width: '60%',
    height: '60%',
    top: '20%',
    left: '20%',
  },
  coverInitials: {
    fontFamily: 'Inter_700Bold',
    fontSize: 28,
  },
  badgeOverlay: {
    position: 'absolute',
    bottom: 8,
    left: 8,
    right: 8,
    alignItems: 'center',
  },
  convertingBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.75)',
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 20,
    gap: 6,
    alignSelf: 'center',
  },
  convertingDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: THEME.colors.primary[500],
  },
  convertingText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 11,
    color: '#FFFFFF',
  },
  completedBadge: {
    position: 'absolute',
    top: 6,
    right: 6,
    backgroundColor: 'rgba(0,0,0,0.6)',
    borderRadius: 12,
  },
  textArea: {
    gap: 3,
  },
  title: {
    fontFamily: 'Inter_600SemiBold',
    color: THEME.colors.text.primary,
    lineHeight: 18,
  },
  author: {
    fontFamily: 'Inter_400Regular',
    color: THEME.colors.text.secondary,
  },
  meta: {
    fontFamily: 'Inter_400Regular',
    fontSize: 10,
    color: THEME.colors.text.muted,
    marginTop: 2,
  },
  progressTrack: {
    height: 3,
    backgroundColor: THEME.colors.border.light,
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: THEME.colors.primary[500],
    borderRadius: 2,
  },
})
