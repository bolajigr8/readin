import React from 'react'
import {
  Animated,
  Image,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native'
import { useSafeAreaInsets } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { router } from 'expo-router'
import { useAudioStore } from '@/store/audioStore'
import { useAudio } from '@/hooks/useAudio'
import { THEME } from '@/constants/theme'
import { getCoverColor } from '@/utils/format'

export function MiniPlayer() {
  const insets = useSafeAreaInsets()
  const {
    isPlaying,
    bookTitle,
    coverUrl,
    currentSentenceIndex,
    totalSentences,
    isMiniPlayerVisible,
  } = useAudioStore()
  const { handlePlay, handlePause, handleStop } = useAudio()

  if (!isMiniPlayerVisible || !bookTitle) return null

  const progress =
    totalSentences > 0 ? currentSentenceIndex / totalSentences : 0
  const color = getCoverColor(bookTitle)

  return (
    <View style={[styles.container, { bottom: insets.bottom + 8 }]}>
      {/* Progress bar */}
      <View style={styles.progressTrack}>
        <View
          style={[
            styles.progressFill,
            {
              width: `${progress * 100}%` as `${number}%`,
              backgroundColor: THEME.colors.primary[500],
            },
          ]}
        />
      </View>

      <View style={styles.row}>
        {/* Cover */}
        <TouchableOpacity
          onPress={() => router.push('/audio-player' as any)}
          activeOpacity={0.8}
        >
          {coverUrl ? (
            <Image source={{ uri: coverUrl }} style={styles.cover} />
          ) : (
            <View style={[styles.cover, { backgroundColor: color + '25' }]}>
              <Ionicons name='book' size={18} color={color} />
            </View>
          )}
        </TouchableOpacity>

        {/* Title */}
        <TouchableOpacity
          style={styles.titleArea}
          onPress={() => router.push('/audio-player' as any)}
          activeOpacity={0.8}
        >
          <Text style={styles.title} numberOfLines={1}>
            {bookTitle}
          </Text>
          <Text style={styles.sub} numberOfLines={1}>
            {totalSentences > 0
              ? `${Math.round(progress * 100)}% listened`
              : 'Listening...'}
          </Text>
        </TouchableOpacity>

        {/* Controls */}
        <View style={styles.controls}>
          <TouchableOpacity
            onPress={isPlaying ? handlePause : handlePlay}
            style={styles.playBtn}
          >
            <Ionicons
              name={isPlaying ? 'pause' : 'play'}
              size={20}
              color='#FFFFFF'
            />
          </TouchableOpacity>
          <TouchableOpacity
            onPress={handleStop}
            hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
          >
            <Ionicons name='close' size={18} color={THEME.colors.text.muted} />
          </TouchableOpacity>
        </View>
      </View>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    left: 8,
    right: 8,
    backgroundColor: THEME.colors.elevated,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: THEME.colors.border.light,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 12,
    elevation: 8,
  },
  progressTrack: {
    height: 2,
    backgroundColor: THEME.colors.border.default,
  },
  progressFill: {
    height: '100%',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 12,
  },
  cover: {
    width: 40,
    height: 40,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  titleArea: { flex: 1, gap: 2 },
  title: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 13,
    color: THEME.colors.text.primary,
  },
  sub: {
    fontFamily: 'Inter_400Regular',
    fontSize: 11,
    color: THEME.colors.text.muted,
  },
  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  playBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: THEME.colors.primary[500],
    alignItems: 'center',
    justifyContent: 'center',
  },
})
