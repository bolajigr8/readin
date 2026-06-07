import React from 'react'
import { View, Text, TouchableOpacity, Image, StyleSheet } from 'react-native'
import { Ionicons } from '@expo/vector-icons'
import { THEME } from '@/constants/theme'
import { getCoverColor, getTitleInitials } from '@/utils/format'
import type { Book } from '@/types'

interface ContinueReadingBannerProps {
  book: Book
  onPress: () => void
}

export const ContinueReadingBanner = React.memo(function ContinueReadingBanner({
  book,
  onPress,
}: ContinueReadingBannerProps) {
  const hasCover = book.coverUrl.length > 0
  const percentage = book.progress?.percentage ?? 0
  const color = getCoverColor(book.title)

  return (
    <TouchableOpacity
      activeOpacity={0.8}
      onPress={onPress}
      style={styles.container}
    >
      {/* Cover thumbnail */}
      <View style={styles.coverWrapper}>
        {hasCover ? (
          <Image
            source={{ uri: book.coverUrl }}
            style={styles.cover}
            resizeMode='cover'
          />
        ) : (
          <View
            style={[
              styles.cover,
              styles.coverFallback,
              {
                backgroundColor: color + '25',
                borderColor: color + '40',
              },
            ]}
          >
            <Text style={[styles.fallbackInitials, { color }]}>
              {getTitleInitials(book.title)}
            </Text>
          </View>
        )}
      </View>

      {/* Content */}
      <View style={styles.content}>
        <View style={styles.badge}>
          <Ionicons
            name='book-outline'
            size={11}
            color={THEME.colors.primary[500]}
          />
          <Text style={styles.badgeText}>Continue Reading</Text>
        </View>

        <Text style={styles.title} numberOfLines={2}>
          {book.title}
        </Text>

        {book.author.length > 0 && (
          <Text style={styles.author} numberOfLines={1}>
            {book.author}
          </Text>
        )}

        {/* Progress */}
        <View style={styles.progressRow}>
          <View style={styles.progressTrack}>
            <View style={[styles.progressFill, { width: `${percentage}%` }]} />
          </View>
          <Text style={styles.percentageText}>{Math.round(percentage)}%</Text>
        </View>
      </View>

      {/* Arrow */}
      <View style={styles.arrow}>
        <Ionicons
          name='chevron-forward'
          size={18}
          color={THEME.colors.primary[500]}
        />
      </View>
    </TouchableOpacity>
  )
})

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: THEME.colors.surface,
    borderWidth: 1,
    borderColor: THEME.colors.primary[500] + '30',
    borderRadius: 14,
    padding: 14,
    gap: 14,
    marginHorizontal: 16,
  },
  coverWrapper: {
    flexShrink: 0,
  },
  cover: {
    width: 68,
    height: 88,
    borderRadius: 8,
  },
  coverFallback: {
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  fallbackInitials: {
    fontFamily: 'Inter_700Bold',
    fontSize: 18,
  },
  content: {
    flex: 1,
    gap: 5,
  },
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    marginBottom: 2,
  },
  badgeText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 11,
    color: THEME.colors.primary[500],
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  title: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 15,
    color: THEME.colors.text.primary,
    lineHeight: 20,
  },
  author: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.secondary,
  },
  progressRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginTop: 4,
  },
  progressTrack: {
    flex: 1,
    height: 4,
    backgroundColor: THEME.colors.border.light,
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: THEME.colors.primary[500],
    borderRadius: 2,
  },
  percentageText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 12,
    color: THEME.colors.primary[500],
    width: 34,
    textAlign: 'right',
  },
  arrow: {
    flexShrink: 0,
  },
})
