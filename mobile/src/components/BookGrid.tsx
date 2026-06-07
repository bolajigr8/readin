import React from 'react'
import {
  FlatList,
  View,
  StyleSheet,
  useWindowDimensions,
  RefreshControl,
} from 'react-native'
import { BookCard } from '@/components/BookCard'
import { THEME } from '@/constants/theme'
import type { Book } from '@/types'

interface BookGridProps {
  books: Book[]
  numColumns?: 1 | 2
  onBookPress: (book: Book) => void
  onRefresh?: () => void
  isRefreshing?: boolean
  ListHeaderComponent?: React.ReactElement | null
  ListFooterComponent?: React.ReactElement | null
  ListEmptyComponent?: React.ReactElement | null
}

const HORIZONTAL_PADDING = 16
const COLUMN_GAP = 12

export function BookGrid({
  books,
  numColumns = 2,
  onBookPress,
  onRefresh,
  isRefreshing = false,
  ListHeaderComponent,
  ListFooterComponent,
  ListEmptyComponent,
}: BookGridProps) {
  const { width } = useWindowDimensions()

  // Calculate card width based on columns
  const cardWidth =
    numColumns === 2
      ? (width - HORIZONTAL_PADDING * 2 - COLUMN_GAP) / 2
      : width - HORIZONTAL_PADDING * 2

  return (
    <FlatList
      data={books}
      key={`grid-${numColumns}`} // forces re-render when column count changes
      numColumns={numColumns}
      keyExtractor={(item) => item._id}
      contentContainerStyle={styles.contentContainer}
      columnWrapperStyle={numColumns === 2 ? styles.row : undefined}
      showsVerticalScrollIndicator={false}
      // Performance optimizations
      removeClippedSubviews={true}
      maxToRenderPerBatch={8}
      windowSize={7}
      updateCellsBatchingPeriod={50}
      initialNumToRender={6}
      getItemLayout={(_, index) => ({
        length: 260 + 8, // approximate card height + gap
        offset: (260 + 8) * Math.floor(index / numColumns),
        index,
      })}
      refreshControl={
        onRefresh !== undefined ? (
          <RefreshControl
            refreshing={isRefreshing}
            onRefresh={onRefresh}
            tintColor={THEME.colors.primary[500]}
            colors={[THEME.colors.primary[500]]}
          />
        ) : undefined
      }
      renderItem={({ item }) => (
        <View style={{ width: cardWidth }}>
          <BookCard book={item} size='md' onPress={() => onBookPress(item)} />
        </View>
      )}
      ListHeaderComponent={ListHeaderComponent}
      ListFooterComponent={ListFooterComponent}
      ListEmptyComponent={ListEmptyComponent}
    />
  )
}

const styles = StyleSheet.create({
  contentContainer: {
    paddingHorizontal: HORIZONTAL_PADDING,
    paddingBottom: 24,
    gap: 12,
    flexGrow: 1,
  },
  row: {
    gap: 12,
    justifyContent: 'space-between',
  },
})
