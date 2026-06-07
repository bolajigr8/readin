import React, { useState, useMemo } from 'react'
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Alert,
} from 'react-native'
import { SafeAreaView } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { router } from 'expo-router'

import { BookGrid } from '@/components/BookGrid'
import { EmptyState } from '@/components/EmptyState'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useLibrary, useDeleteBook } from '@/hooks/useLibrary'
import { useAuth } from '@/hooks/useAuth'
import { THEME } from '@/constants/theme'
import type { Book } from '@/types'
import { AppHeader } from '@/components/AppHeader'

// ── Sort options ──────────────────────────────────────────────────────────────

type SortKey = 'recent' | 'title' | 'author' | 'lastRead'

const SORT_OPTIONS: { key: SortKey; label: string }[] = [
  { key: 'recent', label: 'Recent' },
  { key: 'title', label: 'Title' },
  { key: 'author', label: 'Author' },
  { key: 'lastRead', label: 'Last Read' },
]

function sortBooks(books: Book[], sort: SortKey): Book[] {
  const copy = [...books]
  switch (sort) {
    case 'title':
      return copy.sort((a, b) => a.title.localeCompare(b.title))
    case 'author':
      return copy.sort((a, b) => a.author.localeCompare(b.author))
    case 'lastRead':
      return copy.sort((a, b) => {
        const aTime = a.progress?.lastReadAt ?? '1970-01-01'
        const bTime = b.progress?.lastReadAt ?? '1970-01-01'
        return new Date(bTime).getTime() - new Date(aTime).getTime()
      })
    case 'recent':
    default:
      return copy.sort(
        (a, b) =>
          new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
      )
  }
}

// ── Library Screen ────────────────────────────────────────────────────────────

export default function LibraryScreen() {
  const { user } = useAuth()
  const { data, isLoading, error, refetch, isFetching } = useLibrary()
  const deleteBook = useDeleteBook()

  const [searchQuery, setSearchQuery] = useState('')
  const [sortKey, setSortKey] = useState<SortKey>('recent')
  const [numColumns, setNumColumns] = useState<1 | 2>(2)
  const [showSortMenu, setShowSortMenu] = useState(false)
  const [showFreemiumBanner, setShowFreemiumBanner] = useState(true)

  // ── Filter + sort ─────────────────────────────────────────────────────────

  const processedBooks = useMemo(() => {
    const allBooks = data?.books ?? []
    const readyBooks = allBooks.filter((b) => b.status === 'ready')

    const filtered =
      searchQuery.trim().length === 0
        ? readyBooks
        : readyBooks.filter(
            (b) =>
              b.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
              b.author.toLowerCase().includes(searchQuery.toLowerCase()),
          )

    return sortBooks(filtered, sortKey)
  }, [data?.books, searchQuery, sortKey])

  const limitReached = data?.meta.limitReached === true
  const isFreePlan = user?.plan === 'free'

  // ── Book actions ──────────────────────────────────────────────────────────

  const handleBookPress = (book: Book) => {
    if (book.status === 'converting' || book.status === 'queued') {
      Alert.alert(
        'Still Converting',
        `"${book.title}" is being converted. Please wait.`,
      )
      return
    }
    router.push(`/reader/${book._id}` as Parameters<typeof router.push>[0])
  }

  const handleDeleteBook = (book: Book) => {
    Alert.alert(
      'Delete Book',
      `Remove "${book.title}" from your library? This cannot be undone.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => deleteBook.mutate(book._id),
        },
      ],
    )
  }

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <SafeAreaView
      style={{ flex: 1, backgroundColor: THEME.colors.background }}
      edges={['bottom']}
    >
      {/* Header */}
      <AppHeader
        title='My Library'
        rightContent={
          <TouchableOpacity
            // onPress={() => router.push('/upload')}
            onPress={() => router.push('/upload' as any)}
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          >
            <Ionicons name='add' size={24} color={THEME.colors.primary[500]} />
          </TouchableOpacity>
        }
      />

      {/* Search bar */}
      <View style={styles.searchBar}>
        <Ionicons
          name='search-outline'
          size={17}
          color={THEME.colors.text.muted}
          style={{ marginLeft: 4 }}
        />
        <TextInput
          style={styles.searchInput}
          placeholder='Search by title or author...'
          placeholderTextColor={THEME.colors.text.muted}
          value={searchQuery}
          onChangeText={setSearchQuery}
          autoCapitalize='none'
          autoCorrect={false}
          clearButtonMode='while-editing'
        />
        {searchQuery.length > 0 && (
          <TouchableOpacity onPress={() => setSearchQuery('')}>
            <Ionicons
              name='close-circle'
              size={17}
              color={THEME.colors.text.muted}
            />
          </TouchableOpacity>
        )}
      </View>

      {/* Toolbar — sort + layout toggle */}
      <View style={styles.toolbar}>
        {/* Sort button */}
        <View>
          <TouchableOpacity
            style={styles.sortButton}
            onPress={() => setShowSortMenu((v) => !v)}
          >
            <Ionicons
              name='funnel-outline'
              size={14}
              color={THEME.colors.text.secondary}
            />
            <Text style={styles.sortButtonText}>
              {SORT_OPTIONS.find((o) => o.key === sortKey)?.label ?? 'Sort'}
            </Text>
            <Ionicons
              name={showSortMenu ? 'chevron-up' : 'chevron-down'}
              size={12}
              color={THEME.colors.text.secondary}
            />
          </TouchableOpacity>

          {/* Sort dropdown */}
          {showSortMenu && (
            <View style={styles.sortDropdown}>
              {SORT_OPTIONS.map((option) => (
                <TouchableOpacity
                  key={option.key}
                  style={[
                    styles.sortOption,
                    sortKey === option.key && styles.sortOptionActive,
                  ]}
                  onPress={() => {
                    setSortKey(option.key)
                    setShowSortMenu(false)
                  }}
                >
                  <Text
                    style={[
                      styles.sortOptionText,
                      sortKey === option.key && {
                        color: THEME.colors.primary[500],
                      },
                    ]}
                  >
                    {option.label}
                  </Text>
                  {sortKey === option.key && (
                    <Ionicons
                      name='checkmark'
                      size={14}
                      color={THEME.colors.primary[500]}
                    />
                  )}
                </TouchableOpacity>
              ))}
            </View>
          )}
        </View>

        {/* Book count */}
        <Text style={styles.bookCount}>
          {processedBooks.length}{' '}
          {processedBooks.length === 1 ? 'book' : 'books'}
        </Text>

        {/* Layout toggle */}
        <View style={styles.layoutToggle}>
          <TouchableOpacity
            onPress={() => setNumColumns(2)}
            style={[
              styles.layoutBtn,
              numColumns === 2 && styles.layoutBtnActive,
            ]}
          >
            <Ionicons
              name='grid-outline'
              size={16}
              color={
                numColumns === 2
                  ? THEME.colors.primary[500]
                  : THEME.colors.text.muted
              }
            />
          </TouchableOpacity>
          <TouchableOpacity
            onPress={() => setNumColumns(1)}
            style={[
              styles.layoutBtn,
              numColumns === 1 && styles.layoutBtnActive,
            ]}
          >
            <Ionicons
              name='list-outline'
              size={16}
              color={
                numColumns === 1
                  ? THEME.colors.primary[500]
                  : THEME.colors.text.muted
              }
            />
          </TouchableOpacity>
        </View>
      </View>

      {/* Freemium limit banner */}
      {isFreePlan && limitReached && showFreemiumBanner && (
        <View style={styles.freemiumBanner}>
          <Ionicons
            name='lock-closed-outline'
            size={14}
            color={THEME.colors.amber[400]}
          />
          <Text style={styles.freemiumText}>
            10-book limit reached.{' '}
            <Text
              style={styles.freemiumLink}
              onPress={() => router.push('/(tabs)/profile')}
            >
              Upgrade to Premium
            </Text>{' '}
            for unlimited books.
          </Text>
          <TouchableOpacity onPress={() => setShowFreemiumBanner(false)}>
            <Ionicons name='close' size={14} color={THEME.colors.text.muted} />
          </TouchableOpacity>
        </View>
      )}

      {/* Content */}
      {isLoading ? (
        <LoadingSpinner fullScreen label='Loading library...' />
      ) : error !== null ? (
        <EmptyState
          icon='wifi-outline'
          title='Could not load library'
          description='Check your connection and pull down to retry.'
          actionLabel='Try Again'
          onAction={() => refetch()}
        />
      ) : (
        <BookGrid
          books={processedBooks}
          numColumns={numColumns}
          onBookPress={handleBookPress}
          onRefresh={() => refetch()}
          isRefreshing={isFetching && !isLoading}
          ListHeaderComponent={<View style={{ height: 12 }} />}
          ListEmptyComponent={
            <EmptyState
              icon='book-outline'
              title={
                searchQuery.length > 0
                  ? `No results for "${searchQuery}"`
                  : 'Your library is empty'
              }
              description={
                searchQuery.length > 0
                  ? 'Try a different title or author name.'
                  : 'Upload a PDF or discover a free classic to get started.'
              }
              actionLabel={
                searchQuery.length === 0 ? 'Upload a Book' : undefined
              }
              onAction={
                searchQuery.length === 0
                  ? () => router.push('/upload' as any)
                  : undefined
              }
            />
          }
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
  toolbar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    zIndex: 10,
  },
  sortButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: THEME.colors.surface,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  sortButtonText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    color: THEME.colors.text.secondary,
  },
  sortDropdown: {
    position: 'absolute',
    top: 38,
    left: 0,
    backgroundColor: THEME.colors.elevated,
    borderWidth: 1,
    borderColor: THEME.colors.border.light,
    borderRadius: 10,
    overflow: 'hidden',
    zIndex: 20,
    minWidth: 140,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  sortOption: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 14,
    paddingVertical: 11,
  },
  sortOptionActive: {
    backgroundColor: THEME.colors.primary[500] + '12',
  },
  sortOptionText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    color: THEME.colors.text.primary,
  },
  bookCount: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.muted,
  },
  layoutToggle: {
    flexDirection: 'row',
    backgroundColor: THEME.colors.surface,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    borderRadius: 8,
    overflow: 'hidden',
  },
  layoutBtn: {
    width: 34,
    height: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },
  layoutBtnActive: {
    backgroundColor: THEME.colors.primary[500] + '20',
  },
  freemiumBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: THEME.colors.amber[400] + '12',
    borderWidth: 1,
    borderColor: THEME.colors.amber[400] + '35',
    borderRadius: 10,
    marginHorizontal: 16,
    marginBottom: 4,
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 8,
  },
  freemiumText: {
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.secondary,
    lineHeight: 18,
  },
  freemiumLink: {
    fontFamily: 'Inter_600SemiBold',
    color: THEME.colors.amber[400],
  },
})
