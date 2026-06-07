import React, { useEffect, useRef } from 'react'
import {
  Animated,
  FlatList,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native'
import { useSafeAreaInsets } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { THEME } from '@/constants/theme'
import type { Annotation } from '@/hooks/useAnnotations'

const COLOR_MAP: Record<string, string> = {
  yellow: '#FDE68A',
  green: '#6EE7B7',
  blue: '#93C5FD',
  pink: '#F9A8D4',
  purple: '#C4B5FD',
}

interface AnnotationsListProps {
  annotations: Annotation[]
  isOpen: boolean
  onClose: () => void
  onAnnotationPress: (annotation: Annotation) => void
  onDeleteAnnotation: (id: string) => void
}

function AnnotationItem({
  item,
  onPress,
  onDelete,
}: {
  item: Annotation
  onPress: () => void
  onDelete: () => void
}) {
  const color = COLOR_MAP[item.color] ?? '#FDE68A'

  return (
    <TouchableOpacity
      style={styles.item}
      onPress={onPress}
      activeOpacity={0.75}
    >
      {/* Color indicator */}
      <View style={[styles.colorBar, { backgroundColor: color }]} />

      <View style={styles.itemContent}>
        <Text style={styles.selectedText} numberOfLines={3}>
          {item.selectedText}
        </Text>

        {item.note !== undefined && item.note.length > 0 && (
          <View style={styles.noteRow}>
            <Ionicons
              name='create-outline'
              size={12}
              color={THEME.colors.primary[500]}
            />
            <Text style={styles.noteText} numberOfLines={2}>
              {item.note}
            </Text>
          </View>
        )}

        <Text style={styles.meta}>{item.chapterTitle}</Text>
      </View>

      <TouchableOpacity
        onPress={onDelete}
        style={styles.deleteBtn}
        hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
      >
        <Ionicons
          name='trash-outline'
          size={15}
          color={THEME.colors.error[500]}
        />
      </TouchableOpacity>
    </TouchableOpacity>
  )
}

export function AnnotationsList({
  annotations,
  isOpen,
  onClose,
  onAnnotationPress,
  onDeleteAnnotation,
}: AnnotationsListProps) {
  const insets = useSafeAreaInsets()
  const slideAnim = useRef(new Animated.Value(500)).current
  const [mounted, setMounted] = React.useState(false)

  useEffect(() => {
    if (isOpen) {
      setMounted(true)
      Animated.spring(slideAnim, {
        toValue: 0,
        friction: 9,
        tension: 120,
        useNativeDriver: true,
      }).start()
    } else {
      Animated.timing(slideAnim, {
        toValue: 500,
        duration: 250,
        useNativeDriver: true,
      }).start(() => setMounted(false))
    }
  }, [isOpen, slideAnim])

  if (!mounted) return null

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents='box-none'>
      <TouchableOpacity
        style={StyleSheet.absoluteFill}
        activeOpacity={1}
        onPress={onClose}
      />
      <Animated.View
        style={[
          styles.sheet,
          {
            paddingBottom: insets.bottom + 16,
            transform: [{ translateY: slideAnim }],
          },
        ]}
      >
        {/* Handle + header */}
        <View style={styles.header}>
          <View style={styles.handle} />
          <View style={styles.headerRow}>
            {/* Fixed: use string interpolation to avoid '&' issues */}
            <Text style={styles.headerTitle}>
              {annotations.length > 0
                ? `${'Highlights & Notes'} (${annotations.length})`
                : 'Highlights & Notes'}
            </Text>
            <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
              <Ionicons
                name='close'
                size={20}
                color={THEME.colors.text.secondary}
              />
            </TouchableOpacity>
          </View>
        </View>

        {annotations.length === 0 ? (
          <View style={styles.emptyState}>
            <Ionicons
              name='bookmark-outline'
              size={36}
              color={THEME.colors.text.muted}
            />
            <Text style={styles.emptyTitle}>{'No highlights yet'}</Text>
            <Text style={styles.emptyDesc}>
              {'Select text while reading to highlight or add notes.'}
            </Text>
          </View>
        ) : (
          <FlatList
            data={annotations}
            keyExtractor={(item) => item._id}
            showsVerticalScrollIndicator={false}
            contentContainerStyle={{
              paddingHorizontal: 16,
              gap: 8,
              paddingBottom: 8,
            }}
            renderItem={({ item }) => (
              <AnnotationItem
                item={item}
                onPress={() => onAnnotationPress(item)}
                onDelete={() => onDeleteAnnotation(item._id)}
              />
            )}
          />
        )}
      </Animated.View>
    </View>
  )
}

const styles = StyleSheet.create({
  sheet: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    maxHeight: '70%',
    backgroundColor: THEME.colors.elevated,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    borderTopWidth: 1,
    borderTopColor: THEME.colors.border.light,
  },
  header: {
    alignItems: 'center',
    paddingTop: 12,
    paddingHorizontal: 16,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: THEME.colors.border.default,
    gap: 8,
  },
  handle: {
    width: 36,
    height: 4,
    backgroundColor: THEME.colors.border.light,
    borderRadius: 2,
  },
  headerRow: {
    width: '100%',
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
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
    backgroundColor: THEME.colors.surface,
  },
  item: {
    flexDirection: 'row',
    gap: 12,
    backgroundColor: THEME.colors.surface,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    padding: 12,
    alignItems: 'flex-start',
  },
  colorBar: {
    width: 3,
    borderRadius: 2,
    alignSelf: 'stretch',
    flexShrink: 0,
    minHeight: 40,
  },
  itemContent: {
    flex: 1,
    gap: 5,
  },
  selectedText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.primary,
    lineHeight: 19,
    fontStyle: 'italic',
  },
  noteRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 5,
    marginTop: 2,
  },
  noteText: {
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: THEME.colors.text.secondary,
    lineHeight: 17,
  },
  meta: {
    fontFamily: 'Inter_400Regular',
    fontSize: 11,
    color: THEME.colors.text.muted,
    marginTop: 2,
  },
  deleteBtn: {
    padding: 4,
    flexShrink: 0,
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 48,
    gap: 12,
    paddingHorizontal: 32,
  },
  emptyTitle: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 16,
    color: THEME.colors.text.primary,
  },
  emptyDesc: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.secondary,
    textAlign: 'center',
    lineHeight: 19,
  },
})
