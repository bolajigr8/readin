import React from 'react'
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  Alert,
} from 'react-native'
import { SafeAreaView } from 'react-native-safe-area-context'
import { useSafeAreaInsets } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { router } from 'expo-router'

import { AppHeader } from '@/components/AppHeader'
import { BookCard } from '@/components/BookCard'
import { ContinueReadingBanner } from '@/components/ContinueReadingBanner'
import { UploadProgressCard } from '@/components/UploadProgressCard'
import { EmptyState } from '@/components/EmptyState'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useLibrary, useContinueReading } from '@/hooks/useLibrary'
import { useAuth } from '@/hooks/useAuth'
import { THEME } from '@/constants/theme'
import { getGreeting } from '@/utils/format'
import type { Book } from '@/types'

function handleBookPress(book: Book) {
  if (book.status === 'converting' || book.status === 'queued') {
    Alert.alert(
      'Still Converting',
      `"${book.title}" is being converted to EPUB. It will be ready shortly.`,
    )
    return
  }
  if (book.status === 'failed') {
    Alert.alert(
      'Conversion Failed',
      `"${book.title}" could not be converted. Please try uploading again.`,
    )
    return
  }
  router.push(`/reader/${book._id}` as Parameters<typeof router.push>[0])
}

export default function HomeScreen() {
  const { user } = useAuth()
  const { data, isLoading, error } = useLibrary()
  const continueReading = useContinueReading()
  const insets = useSafeAreaInsets()

  const greeting = getGreeting()
  const firstName = user?.displayName.split(' ')[0] ?? 'Reader'

  const recentBooks = (data?.books ?? [])
    .filter((b) => b.status === 'ready')
    .slice(0, 6)

  const hasBooks = recentBooks.length > 0

  return (
    <SafeAreaView
      style={{ flex: 1, backgroundColor: THEME.colors.background }}
      edges={['bottom']}
    >
      <AppHeader
        title='Home'
        rightContent={
          <TouchableOpacity
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          >
            <Ionicons
              name='notifications-outline'
              size={22}
              color={THEME.colors.text.secondary}
            />
          </TouchableOpacity>
        }
      />

      <FlatList
        data={[]}
        keyExtractor={() => 'dummy'}
        renderItem={null}
        showsVerticalScrollIndicator={false}
        ListHeaderComponent={
          <View style={{ paddingTop: 20, paddingBottom: 100, gap: 28 }}>
            {/* Greeting */}
            <View style={styles.greeting}>
              <Text style={styles.greetingText}>
                {greeting},{' '}
                <Text style={styles.greetingName}>{firstName} 👋</Text>
              </Text>
              <Text style={styles.greetingSub}>
                {hasBooks
                  ? `You have ${data?.meta.total ?? 0} books in your library`
                  : 'Start by uploading your first book'}
              </Text>
            </View>

            {/* Active uploads */}
            <UploadProgressCard />

            {/* Continue reading */}
            {continueReading.length > 0 && (
              <View style={styles.section}>
                <Text style={styles.sectionTitle}>Continue Reading</Text>
                <ContinueReadingBanner
                  book={continueReading[0]!}
                  onPress={() => handleBookPress(continueReading[0]!)}
                />
              </View>
            )}

            {/* Recent books */}
            <View style={styles.section}>
              <View style={styles.sectionHeader}>
                <Text style={styles.sectionTitle}>Recent Books</Text>
                {hasBooks && (
                  <TouchableOpacity
                    onPress={() => router.push('/(tabs)/library')}
                  >
                    <Text style={styles.seeAll}>See all →</Text>
                  </TouchableOpacity>
                )}
              </View>

              {isLoading ? (
                <View style={{ height: 180 }}>
                  <LoadingSpinner />
                </View>
              ) : error !== null ? (
                <View style={{ height: 180 }}>
                  <EmptyState
                    icon='wifi-outline'
                    title='Connection error'
                    description='Could not load your library. Check your connection.'
                  />
                </View>
              ) : !hasBooks ? (
                <View style={{ height: 220 }}>
                  {/*
                    EmptyState uses `onAction` (not `onPress`) — that's the
                    prop name defined in EmptyStateProps. TouchableOpacity
                    uses `onPress`. They are different components with
                    different prop names. Don't swap them.
                  */}
                  <EmptyState
                    icon='book-outline'
                    title='No books yet'
                    description='Upload a PDF or discover a free classic to get started.'
                    actionLabel='Upload a Book'
                    onAction={() => router.push('/upload' as any)}
                  />
                </View>
              ) : (
                <FlatList
                  data={recentBooks}
                  horizontal
                  keyExtractor={(item) => item._id}
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={styles.horizontalList}
                  ItemSeparatorComponent={() => <View style={{ width: 12 }} />}
                  renderItem={({ item }) => (
                    <View style={{ width: 120 }}>
                      <BookCard
                        book={item}
                        size='sm'
                        onPress={() => handleBookPress(item)}
                      />
                    </View>
                  )}
                />
              )}
            </View>
          </View>
        }
      />

      {/*
        FAB is a TouchableOpacity — it uses `onPress`, not `onAction`.
        `onAction` only exists on EmptyState. These are different components.
      */}
      <TouchableOpacity
        style={[styles.fab, { bottom: Math.max(insets.bottom, 16) + 16 }]}
        activeOpacity={0.85}
        onPress={() => router.push('/upload' as any)}
      >
        <Ionicons name='add' size={28} color='#FFFFFF' />
      </TouchableOpacity>
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  greeting: {
    paddingHorizontal: 16,
    gap: 4,
  },
  greetingText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 22,
    color: THEME.colors.text.primary,
  },
  greetingName: {
    fontFamily: 'Inter_700Bold',
    color: THEME.colors.primary[500],
  },
  greetingSub: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    color: THEME.colors.text.secondary,
  },
  section: {
    gap: 14,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
  },
  sectionTitle: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 17,
    color: THEME.colors.text.primary,
  },
  seeAll: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    color: THEME.colors.primary[500],
  },
  horizontalList: {
    paddingHorizontal: 16,
    paddingBottom: 4,
  },
  fab: {
    position: 'absolute',
    right: 20,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: THEME.colors.primary[500],
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: THEME.colors.primary[500],
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 8,
  },
})
