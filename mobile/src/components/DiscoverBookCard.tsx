import React from 'react'
import { Image, StyleSheet, Text, TouchableOpacity, View } from 'react-native'
import { Ionicons } from '@expo/vector-icons'
import { THEME } from '@/constants/theme'
import {
  formatAuthorName,
  getCoverUrl,
  type GutenbergBook,
} from '@/services/gutendex'
import { getCoverColor, getTitleInitials } from '@/utils/format'

interface DiscoverBookCardProps {
  book: GutenbergBook
  onPress: () => void
  isInLibrary?: boolean
}

function CoverFallback({ title }: { title: string }) {
  const color = getCoverColor(title)
  return (
    <View
      style={[
        styles.fallback,
        { backgroundColor: color + '20', borderColor: color + '40' },
      ]}
    >
      <Text style={[styles.fallbackText, { color }]}>
        {getTitleInitials(title)}
      </Text>
    </View>
  )
}

export const DiscoverBookCard = React.memo(function DiscoverBookCard({
  book,
  onPress,
  isInLibrary = false,
}: DiscoverBookCardProps) {
  const coverUrl = getCoverUrl(book.formats)
  const authors = book.authors
    .map((a) => formatAuthorName(a.name))
    .slice(0, 2)
    .join(', ')

  return (
    <TouchableOpacity
      style={styles.container}
      onPress={onPress}
      activeOpacity={0.78}
    >
      {/* Cover */}
      <View style={styles.coverWrap}>
        {coverUrl ? (
          <Image
            source={{ uri: coverUrl }}
            style={styles.cover}
            resizeMode='cover'
          />
        ) : (
          <CoverFallback title={book.title} />
        )}
        {isInLibrary && (
          <View style={styles.libraryBadge}>
            <Ionicons name='checkmark' size={10} color='#FFFFFF' />
          </View>
        )}
      </View>

      {/* Info */}
      <View style={styles.info}>
        <Text style={styles.title} numberOfLines={2}>
          {book.title}
        </Text>
        {authors.length > 0 && (
          <Text style={styles.author} numberOfLines={1}>
            {authors}
          </Text>
        )}
        <View style={styles.meta}>
          <Ionicons
            name='cloud-download-outline'
            size={11}
            color={THEME.colors.text.muted}
          />
          <Text style={styles.metaText}>
            {(book.download_count / 1000).toFixed(0)}k
          </Text>
        </View>
      </View>
    </TouchableOpacity>
  )
})

const styles = StyleSheet.create({
  container: {
    width: 130,
    gap: 8,
  },
  coverWrap: { position: 'relative' },
  cover: {
    width: 130,
    height: 170,
    borderRadius: 10,
    backgroundColor: THEME.colors.surface,
  },
  fallback: {
    width: 130,
    height: 170,
    borderRadius: 10,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  fallbackText: {
    fontFamily: 'Inter_700Bold',
    fontSize: 28,
  },
  libraryBadge: {
    position: 'absolute',
    top: 6,
    right: 6,
    width: 18,
    height: 18,
    borderRadius: 9,
    backgroundColor: THEME.colors.success[500],
    alignItems: 'center',
    justifyContent: 'center',
  },
  info: { gap: 4 },
  title: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 12,
    color: THEME.colors.text.primary,
    lineHeight: 17,
  },
  author: {
    fontFamily: 'Inter_400Regular',
    fontSize: 11,
    color: THEME.colors.text.secondary,
  },
  meta: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
  },
  metaText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 11,
    color: THEME.colors.text.muted,
  },
})
