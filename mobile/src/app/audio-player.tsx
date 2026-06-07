import React from 'react'
import { Image, StyleSheet, Text, TouchableOpacity, View } from 'react-native'
import { SafeAreaView } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { router } from 'expo-router'
import { useAudioStore } from '@/store/audioStore'
import { useAudio } from '@/hooks/useAudio'
import { getCoverColor } from '@/utils/format'
import { THEME } from '@/constants/theme'

const SPEED_OPTIONS = [0.75, 1.0, 1.25, 1.5, 2.0] as const

export default function AudioPlayerScreen() {
  const {
    isPlaying,
    bookTitle,
    coverUrl,
    currentSentenceIndex,
    totalSentences,
    speed,
    setSpeed,
  } = useAudioStore()

  const { handlePlay, handlePause, handleStop, handleSeek } = useAudio()
  const progress =
    totalSentences > 0 ? currentSentenceIndex / totalSentences : 0
  const color = getCoverColor(bookTitle ?? 'Book')

  return (
    <SafeAreaView
      style={{ flex: 1, backgroundColor: THEME.colors.background }}
      edges={['top', 'bottom']}
    >
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.iconBtn}>
          <Ionicons
            name='chevron-down'
            size={24}
            color={THEME.colors.text.primary}
          />
        </TouchableOpacity>
        <View style={styles.headerTitle}>
          <Text style={styles.headerLabel}>Now Listening</Text>
        </View>
        <View style={{ width: 40 }} />
      </View>

      {/* Cover art */}
      <View style={styles.coverSection}>
        <View style={[styles.coverShadow, { shadowColor: color }]}>
          {coverUrl ? (
            <Image
              source={{ uri: coverUrl }}
              style={styles.coverLarge}
              resizeMode='cover'
            />
          ) : (
            <View
              style={[
                styles.coverLarge,
                styles.coverFallback,
                { backgroundColor: color + '25' },
              ]}
            >
              <Ionicons name='headset' size={60} color={color} />
            </View>
          )}
        </View>
      </View>

      {/* Book info */}
      <View style={styles.infoSection}>
        <Text style={styles.bookTitle} numberOfLines={2}>
          {bookTitle ?? 'Unknown Book'}
        </Text>
        <Text style={styles.bookSub}>Text-to-speech preview</Text>
      </View>

      {/* Progress bar */}
      <View style={styles.progressSection}>
        <View style={styles.progressTrack}>
          <View
            style={[
              styles.progressFill,
              { width: `${progress * 100}%` as `${number}%` },
            ]}
          />
        </View>
        <View style={styles.progressLabels}>
          <Text style={styles.progressText}>{currentSentenceIndex}</Text>
          <Text style={styles.progressText}>{totalSentences} sentences</Text>
        </View>
      </View>

      {/* Speed selector */}
      <View style={styles.speedSection}>
        <Text style={styles.speedLabel}>Speed</Text>
        <View style={styles.speedBtns}>
          {SPEED_OPTIONS.map((s) => (
            <TouchableOpacity
              key={s}
              onPress={() => setSpeed(s)}
              style={[styles.speedBtn, speed === s && styles.speedBtnActive]}
            >
              <Text
                style={[
                  styles.speedBtnText,
                  speed === s && { color: THEME.colors.primary[500] },
                ]}
              >
                {s}×
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Controls */}
      <View style={styles.controls}>
        {/* Seek back 5 sentences */}
        <TouchableOpacity
          onPress={() => handleSeek(Math.max(0, currentSentenceIndex - 5))}
          style={styles.controlBtn}
        >
          <Ionicons
            name='play-skip-back-outline'
            size={28}
            color={THEME.colors.text.secondary}
          />
        </TouchableOpacity>

        {/* Play / Pause */}
        <TouchableOpacity
          onPress={isPlaying ? handlePause : handlePlay}
          style={styles.playBtn}
          activeOpacity={0.85}
        >
          <Ionicons
            name={isPlaying ? 'pause' : 'play'}
            size={30}
            color='#FFFFFF'
          />
        </TouchableOpacity>

        {/* Seek forward 5 sentences */}
        <TouchableOpacity
          onPress={() =>
            handleSeek(Math.min(totalSentences - 1, currentSentenceIndex + 5))
          }
          style={styles.controlBtn}
        >
          <Ionicons
            name='play-skip-forward-outline'
            size={28}
            color={THEME.colors.text.secondary}
          />
        </TouchableOpacity>
      </View>

      {/* Stop */}
      <TouchableOpacity
        onPress={async () => {
          await handleStop()
          router.back()
        }}
        style={styles.stopBtn}
      >
        <Text style={styles.stopBtnText}>Stop & Close</Text>
      </TouchableOpacity>
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
  },
  iconBtn: {
    width: 40,
    height: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTitle: { flex: 1, alignItems: 'center' },
  headerLabel: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    color: THEME.colors.text.muted,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
  coverSection: {
    alignItems: 'center',
    paddingVertical: 32,
  },
  coverShadow: {
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.5,
    shadowRadius: 24,
    elevation: 12,
  },
  coverLarge: {
    width: 220,
    height: 220,
    borderRadius: 20,
  },
  coverFallback: {
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
  },
  infoSection: {
    alignItems: 'center',
    paddingHorizontal: 32,
    gap: 6,
  },
  bookTitle: {
    fontFamily: 'Inter_700Bold',
    fontSize: 22,
    color: THEME.colors.text.primary,
    textAlign: 'center',
    lineHeight: 30,
  },
  bookSub: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    color: THEME.colors.text.muted,
  },
  progressSection: {
    paddingHorizontal: 24,
    paddingTop: 28,
    gap: 8,
  },
  progressTrack: {
    height: 4,
    backgroundColor: THEME.colors.border.default,
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: THEME.colors.primary[500],
    borderRadius: 2,
  },
  progressLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  progressText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: THEME.colors.text.muted,
  },
  speedSection: {
    paddingHorizontal: 24,
    paddingTop: 20,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  speedLabel: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    color: THEME.colors.text.secondary,
  },
  speedBtns: { flexDirection: 'row', gap: 6 },
  speedBtn: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 8,
    backgroundColor: THEME.colors.surface,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
  },
  speedBtnActive: {
    borderColor: THEME.colors.primary[500],
    backgroundColor: THEME.colors.primary[500] + '15',
  },
  speedBtnText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    color: THEME.colors.text.secondary,
  },
  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 40,
    paddingTop: 32,
  },
  controlBtn: {
    width: 52,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
  },
  playBtn: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: THEME.colors.primary[500],
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: THEME.colors.primary[500],
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 8,
  },
  stopBtn: {
    marginHorizontal: 40,
    marginTop: 24,
    paddingVertical: 12,
    borderRadius: 10,
    alignItems: 'center',
    backgroundColor: THEME.colors.surface,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
  },
  stopBtnText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 14,
    color: THEME.colors.text.muted,
  },
})
