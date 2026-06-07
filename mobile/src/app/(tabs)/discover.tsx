import React, { useState, useCallback } from 'react'
import {
  View,
  Text,
  TextInput,
  FlatList,
  TouchableOpacity,
  ActivityIndicator,
  StyleSheet,
} from 'react-native'
import { SafeAreaView } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { router } from 'expo-router'
import { AppHeader } from '@/components/AppHeader'
import { DiscoverBookCard } from '@/components/DiscoverBookCard'
import { EmptyState } from '@/components/EmptyState'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import {
  usePopularBooks,
  useSearchBooks,
  useBrowseCategory,
} from '@/hooks/useDiscover'
import { useLibrary } from '@/hooks/useLibrary'
import { CATEGORIES } from '@/services/gutendex'
import { THEME } from '@/constants/theme'
import type { GutenbergBook } from '@/services/gutendex'

export default function DiscoverScreen() {
  const [searchQuery, setSearchQuery] = useState('')
  const [activeCategory, setActiveCategory] = useState<string | null>(null)
  const [isSearching, setIsSearching] = useState(false)

  const { data: libraryData } = useLibrary()
  const libraryGutenbergIds = new Set(
    (libraryData?.books ?? []).map((b) => b.gutenbergId).filter(Boolean),
  )

  // Choose query source based on state
  const popularQuery = usePopularBooks()
  const searchResultsQuery = useSearchBooks(searchQuery)
  const categoryQuery = useBrowseCategory(activeCategory ?? '')

  const activeQuery = isSearching
    ? searchResultsQuery
    : activeCategory
      ? categoryQuery
      : popularQuery

  const allBooks = activeQuery.data?.pages.flatMap((p) => p.results) ?? []

  const loadMore = () => {
    if (activeQuery.hasNextPage && !activeQuery.isFetchingNextPage) {
      void activeQuery.fetchNextPage()
    }
  }

  const handleBookPress = (book: GutenbergBook) => {
    router.push(`/book-detail/${book.id}` as any)
  }

  const handleSearch = useCallback((text: string) => {
    setSearchQuery(text)
    setIsSearching(text.trim().length >= 2)
    if (text.trim().length >= 2) setActiveCategory(null)
  }, [])

  const handleCategoryPress = (categoryId: string) => {
    if (activeCategory === categoryId) {
      setActiveCategory(null)
    } else {
      setActiveCategory(categoryId)
      setIsSearching(false)
      setSearchQuery('')
    }
  }

  return (
    <SafeAreaView
      style={{ flex: 1, backgroundColor: THEME.colors.background }}
      edges={['bottom']}
    >
      <AppHeader
        title='Discover'
        rightContent={
          <Ionicons
            name='library-outline'
            size={22}
            color={THEME.colors.text.secondary}
          />
        }
      />

      {/* Search bar */}
      <View style={styles.searchBar}>
        <Ionicons
          name='search-outline'
          size={17}
          color={THEME.colors.text.muted}
        />
        <TextInput
          style={styles.searchInput}
          placeholder='Search 70,000+ free books...'
          placeholderTextColor={THEME.colors.text.muted}
          value={searchQuery}
          onChangeText={handleSearch}
          autoCapitalize='none'
          autoCorrect={false}
          returnKeyType='search'
        />
        {searchQuery.length > 0 && (
          <TouchableOpacity
            onPress={() => {
              setSearchQuery('')
              setIsSearching(false)
            }}
          >
            <Ionicons
              name='close-circle'
              size={17}
              color={THEME.colors.text.muted}
            />
          </TouchableOpacity>
        )}
      </View>

      {/* Category chips */}
      {!isSearching && (
        <FlatList
          data={CATEGORIES}
          horizontal
          keyExtractor={(item) => item.id}
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.chips}
          renderItem={({ item }) => {
            const isActive = activeCategory === item.id
            return (
              <TouchableOpacity
                onPress={() => handleCategoryPress(item.id)}
                style={[
                  styles.chip,
                  isActive && {
                    backgroundColor: THEME.colors.primary[500] + '20',
                    borderColor: THEME.colors.primary[500] + '60',
                  },
                ]}
              >
                <Text style={styles.chipEmoji}>{item.icon}</Text>
                <Text
                  style={[
                    styles.chipLabel,
                    isActive && { color: THEME.colors.primary[500] },
                  ]}
                >
                  {item.label}
                </Text>
              </TouchableOpacity>
            )
          }}
        />
      )}

      {/* Section header */}
      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>
          {isSearching
            ? `Results for "${searchQuery}"`
            : activeCategory
              ? (CATEGORIES.find((c) => c.id === activeCategory)?.label ??
                'Books')
              : 'Most Popular'}
        </Text>
        {activeQuery.data !== undefined && (
          <Text>
            {(activeQuery.data.pages[0]?.count ?? 0).toLocaleString()} books
          </Text>
        )}
      </View>

      {/* Book grid */}
      {activeQuery.isLoading ? (
        <LoadingSpinner fullScreen label='Loading books...' />
      ) : activeQuery.isError ? (
        <EmptyState
          icon='wifi-outline'
          title='Could not load books'
          description='Check your internet connection. Gutenberg requires internet access.'
          actionLabel='Try Again'
          onAction={() => void activeQuery.refetch()}
        />
      ) : allBooks.length === 0 ? (
        <EmptyState
          icon='search-outline'
          title='No books found'
          description={`No results for "${searchQuery}". Try a different search.`}
        />
      ) : (
        <FlatList
          data={allBooks}
          keyExtractor={(item) => String(item.id)}
          numColumns={3}
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.grid}
          columnWrapperStyle={styles.row}
          onEndReached={loadMore}
          onEndReachedThreshold={0.5}
          removeClippedSubviews
          maxToRenderPerBatch={9}
          windowSize={7}
          ListFooterComponent={
            activeQuery.isFetchingNextPage ? (
              <ActivityIndicator
                color={THEME.colors.primary[500]}
                style={{ padding: 24 }}
              />
            ) : null
          }
          renderItem={({ item }) => (
            <DiscoverBookCard
              book={item}
              onPress={() => handleBookPress(item)}
              isInLibrary={libraryGutenbergIds.has(String(item.id))}
            />
          )}
        />
      )}
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: THEME.colors.surface,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    borderRadius: 10,
    marginHorizontal: 16,
    marginTop: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 8,
  },
  searchInput: {
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 15,
    color: THEME.colors.text.primary,
    padding: 0,
  },
  chips: {
    paddingHorizontal: 16,
    paddingVertical: 12,
    gap: 8,
  },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: 20,
    backgroundColor: THEME.colors.surface,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
  },
  chipEmoji: { fontSize: 14 },
  chipLabel: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    color: THEME.colors.text.secondary,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingBottom: 12,
  },
  sectionTitle: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 16,
    color: THEME.colors.text.primary,
  },
  bookCount: {
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: THEME.colors.text.muted,
  },
  grid: {
    paddingHorizontal: 16,
    paddingBottom: 24,
    gap: 16,
  },
  row: {
    gap: 12,
    justifyContent: 'flex-start',
  },
})
