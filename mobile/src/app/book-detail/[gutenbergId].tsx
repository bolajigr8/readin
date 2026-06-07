import React, { useState } from 'react'
import {
  Image,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  Alert,
} from 'react-native'
import { SafeAreaView } from 'react-native-safe-area-context'
import { useSafeAreaInsets } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { router, useLocalSearchParams } from 'expo-router'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { EmptyState } from '@/components/EmptyState'
import { useGutenbergBook, useAddToLibrary } from '@/hooks/useDiscover'
import { useLibrary } from '@/hooks/useLibrary'
import { useAudioStore } from '@/store/audioStore'
import { toast } from '@/context/ToastContext'
import { formatAuthorName, getCoverUrl, getEpubUrl } from '@/services/gutendex'
import { getCoverColor } from '@/utils/format'
import { THEME } from '@/constants/theme'

export default function BookDetailScreen() {
  const params = useLocalSearchParams<{ gutenbergId: string }>()
  const gutenbergId = parseInt(
    Array.isArray(params.gutenbergId)
      ? (params.gutenbergId[0] ?? '0')
      : (params.gutenbergId ?? '0'),
    10,
  )

  const { data: book, isLoading, error } = useGutenbergBook(gutenbergId)
  const { data: libraryData } = useLibrary()
  const addToLibrary = useAddToLibrary()
  const loadBookForAudio = useAudioStore((s) => s.loadBook)

  const insets = useSafeAreaInsets()

  const isInLibrary =
    libraryData?.books.some((b) => b.gutenbergId === String(gutenbergId)) ??
    false

  const handleAddToLibrary = async () => {
    if (!book) return
    if (!getEpubUrl(book.formats)) {
      Alert.alert(
        'Not Available',
        'This book does not have an EPUB version available for download.',
      )
      return
    }

    try {
      await addToLibrary.mutateAsync(book)
      toast.success(`"${book.title}" added to your library!`)
    } catch {
      toast.error('Could not add book. Check your connection.')
    }
  }

  const handleListen = () => {
    if (!book) return
    const text =
      book.subjects.length > 0
        ? `${book.title} by ${formatAuthorName(book.authors[0]?.name ?? 'Unknown')}. ${book.subjects.join('. ')}.`
        : `${book.title}. By ${formatAuthorName(book.authors[0]?.name ?? 'Unknown')}. Published by Project Gutenberg.`

    loadBookForAudio(
      String(book.id),
      book.title,
      getCoverUrl(book.formats),
      text,
    )
    router.push('/audio-player' as any)
  }

  if (isLoading) return <LoadingSpinner fullScreen label='Loading book...' />

  if (error || !book) {
    return (
      <SafeAreaView
        style={{ flex: 1, backgroundColor: THEME.colors.background }}
      >
        <EmptyState
          icon='alert-circle-outline'
          title='Book not found'
          description='This book could not be loaded from Project Gutenberg.'
          actionLabel='Go Back'
          onAction={() => router.back()}
        />
      </SafeAreaView>
    )
  }

  const coverUrl = getCoverUrl(book.formats)
  const authors = book.authors.map((a) => formatAuthorName(a.name)).join(', ')
  const epubAvailable = getEpubUrl(book.formats) !== null
  const color = getCoverColor(book.title)

  return (
    <SafeAreaView
      style={{ flex: 1, backgroundColor: THEME.colors.background }}
      edges={['bottom']}
    >
      {/* Back button */}
      <TouchableOpacity
        onPress={() => router.back()}
        style={[styles.backBtn, { top: insets.top + 8 }]}
        hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
      >
        <Ionicons
          name='arrow-back'
          size={20}
          color={THEME.colors.text.primary}
        />
      </TouchableOpacity>

      <ScrollView showsVerticalScrollIndicator={false}>
        {/* Hero */}
        <View style={styles.hero}>
          {coverUrl ? (
            <Image
              source={{ uri: coverUrl }}
              style={styles.cover}
              resizeMode='cover'
            />
          ) : (
            <View
              style={[
                styles.cover,
                styles.coverFallback,
                { backgroundColor: color + '25' },
              ]}
            >
              <Text style={[styles.coverInitials, { color }]}>
                {book.title.slice(0, 2).toUpperCase()}
              </Text>
            </View>
          )}
        </View>

        <View style={styles.content}>
          <Text style={styles.title}>{book.title}</Text>
          {authors.length > 0 && <Text style={styles.author}>{authors}</Text>}

          {/* Stats */}
          <View style={styles.stats}>
            <View style={styles.stat}>
              <Ionicons
                name='cloud-download-outline'
                size={14}
                color={THEME.colors.text.muted}
              />
              <Text style={styles.statText}>
                {(book.download_count / 1000).toFixed(0)}k downloads
              </Text>
            </View>
            <View style={styles.stat}>
              <Ionicons
                name='language-outline'
                size={14}
                color={THEME.colors.text.muted}
              />
              <Text style={styles.statText}>
                {book.languages[0]?.toUpperCase() ?? 'EN'}
              </Text>
            </View>
            <View style={styles.stat}>
              <Ionicons
                name='shield-checkmark-outline'
                size={14}
                color={THEME.colors.success[500]}
              />
              <Text
                style={[styles.statText, { color: THEME.colors.success[500] }]}
              >
                Free Forever
              </Text>
            </View>
          </View>

          {/* Actions */}
          <View style={styles.actions}>
            <TouchableOpacity
              style={[
                styles.primaryBtn,
                (!epubAvailable || isInLibrary) && styles.primaryBtnDisabled,
              ]}
              onPress={handleAddToLibrary}
              disabled={!epubAvailable || isInLibrary || addToLibrary.isPending}
              activeOpacity={0.85}
            >
              <Ionicons
                name={isInLibrary ? 'checkmark-circle' : 'add-circle-outline'}
                size={20}
                color={isInLibrary ? THEME.colors.success[500] : '#FFFFFF'}
              />
              <Text
                style={[
                  styles.primaryBtnText,
                  isInLibrary && { color: THEME.colors.success[500] },
                ]}
              >
                {addToLibrary.isPending
                  ? 'Adding...'
                  : isInLibrary
                    ? 'In Library'
                    : !epubAvailable
                      ? 'No EPUB Available'
                      : 'Add to Library'}
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.secondaryBtn}
              onPress={handleListen}
              activeOpacity={0.8}
            >
              <Ionicons
                name='headset-outline'
                size={18}
                color={THEME.colors.primary[500]}
              />
              <Text style={styles.secondaryBtnText}>Listen Preview</Text>
            </TouchableOpacity>
          </View>

          {/* Subjects */}
          {book.subjects.length > 0 && (
            <View style={styles.section}>
              <Text style={styles.sectionLabel}>SUBJECTS</Text>
              <View style={styles.tags}>
                {book.subjects.slice(0, 6).map((subject, i) => (
                  <View key={i} style={styles.tag}>
                    <Text style={styles.tagText} numberOfLines={1}>
                      {subject.split('--')[0]?.trim() ?? subject}
                    </Text>
                  </View>
                ))}
              </View>
            </View>
          )}

          {/* Bookshelves */}
          {book.bookshelves.length > 0 && (
            <View style={styles.section}>
              <Text style={styles.sectionLabel}>SHELVES</Text>
              <View style={styles.tags}>
                {book.bookshelves.slice(0, 4).map((shelf, i) => (
                  <View
                    key={i}
                    style={[
                      styles.tag,
                      {
                        borderColor: THEME.colors.primary[500] + '40',
                        backgroundColor: THEME.colors.primary[500] + '10',
                      },
                    ]}
                  >
                    <Text
                      style={[
                        styles.tagText,
                        { color: THEME.colors.primary[500] },
                      ]}
                      numberOfLines={1}
                    >
                      {shelf}
                    </Text>
                  </View>
                ))}
              </View>
            </View>
          )}

          {/* Attribution */}
          <View style={styles.attribution}>
            <Ionicons
              name='information-circle-outline'
              size={14}
              color={THEME.colors.text.muted}
            />
            <Text style={styles.attributionText}>
              This book is from Project Gutenberg — public domain, free to read
              and share.
            </Text>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  backBtn: {
    position: 'absolute',
    left: 16,
    zIndex: 10,
    width: 36,
    height: 36,
    borderRadius: 10,
    backgroundColor: THEME.colors.surface + 'CC',
    alignItems: 'center',
    justifyContent: 'center',
  },
  hero: {
    alignItems: 'center',
    paddingTop: 80,
    paddingBottom: 24,
    backgroundColor: THEME.colors.surface,
    borderBottomWidth: 1,
    borderBottomColor: THEME.colors.border.default,
  },
  cover: {
    width: 160,
    height: 210,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.4,
    shadowRadius: 16,
    elevation: 8,
  },
  coverFallback: {
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
  },
  coverInitials: {
    fontFamily: 'Inter_700Bold',
    fontSize: 40,
  },
  content: {
    padding: 24,
    gap: 16,
  },
  title: {
    fontFamily: 'Inter_700Bold',
    fontSize: 24,
    color: THEME.colors.text.primary,
    lineHeight: 32,
  },
  author: {
    fontFamily: 'Inter_400Regular',
    fontSize: 16,
    color: THEME.colors.text.secondary,
  },
  stats: {
    flexDirection: 'row',
    gap: 16,
    flexWrap: 'wrap',
  },
  stat: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
  },
  statText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.muted,
  },
  actions: {
    gap: 10,
  },
  primaryBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    backgroundColor: THEME.colors.primary[500],
    borderRadius: 12,
    paddingVertical: 14,
  },
  primaryBtnDisabled: {
    backgroundColor: THEME.colors.surface,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
  },
  primaryBtnText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 16,
    color: '#FFFFFF',
  },
  secondaryBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    backgroundColor: THEME.colors.surface,
    borderWidth: 1,
    borderColor: THEME.colors.primary[500] + '50',
    borderRadius: 12,
    paddingVertical: 12,
  },
  secondaryBtnText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 15,
    color: THEME.colors.primary[500],
  },
  section: { gap: 10 },
  sectionLabel: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 10,
    letterSpacing: 1,
    color: THEME.colors.text.muted,
  },
  tags: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  tag: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    backgroundColor: THEME.colors.surface,
    maxWidth: 200,
  },
  tagText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: THEME.colors.text.secondary,
  },
  attribution: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 8,
    paddingTop: 8,
  },
  attributionText: {
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: THEME.colors.text.muted,
    lineHeight: 18,
  },
})
