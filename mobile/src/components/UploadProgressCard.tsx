import React, { useEffect, useRef } from 'react'
import {
  View,
  Text,
  Animated,
  StyleSheet,
  TouchableOpacity,
} from 'react-native'
import { Ionicons } from '@expo/vector-icons'
import { THEME } from '@/constants/theme'
import { useLibraryStore } from '@/store/libraryStore'
import type { ActiveUpload } from '@/types'

// ── Status config ─────────────────────────────────────────────────────────────

const STATUS_CONFIG = {
  uploading: {
    label: 'Uploading...',
    color: THEME.colors.primary[500],
    icon: 'cloud-upload-outline' as const,
  },
  queued: {
    label: 'Queued for conversion',
    color: THEME.colors.amber[500],
    icon: 'time-outline' as const,
  },
  converting: {
    label: 'Converting to EPUB...',
    color: THEME.colors.primary[500],
    icon: 'sync-outline' as const,
  },
  ready: {
    label: 'Ready to read! 🎉',
    color: THEME.colors.success[500],
    icon: 'checkmark-circle-outline' as const,
  },
  failed: {
    label: 'Conversion failed',
    color: THEME.colors.error[500],
    icon: 'alert-circle-outline' as const,
  },
} as const

// ── Animated icon for converting state ───────────────────────────────────────

function SpinningIcon({
  name,
  color,
  spinning,
}: {
  name: keyof typeof Ionicons.glyphMap
  color: string
  spinning: boolean
}) {
  const spinAnim = useRef(new Animated.Value(0)).current

  useEffect(() => {
    if (!spinning) return
    const spin = Animated.loop(
      Animated.timing(spinAnim, {
        toValue: 1,
        duration: 1200,
        useNativeDriver: true,
      }),
    )
    spin.start()
    return () => spin.stop()
  }, [spinning, spinAnim])

  const rotate = spinAnim.interpolate({
    inputRange: [0, 1],
    outputRange: ['0deg', '360deg'],
  })

  return (
    <Animated.View style={spinning ? { transform: [{ rotate }] } : undefined}>
      <Ionicons name={name} size={18} color={color} />
    </Animated.View>
  )
}

// ── Single upload card ────────────────────────────────────────────────────────

function UploadItem({ upload }: { upload: ActiveUpload }) {
  const removeUpload = useLibraryStore((s) => s.removeUpload)
  const config = STATUS_CONFIG[upload.status]
  const isSpinning =
    upload.status === 'converting' || upload.status === 'uploading'

  return (
    <View style={styles.item}>
      {/* Icon */}
      <View
        style={[
          styles.iconWrap,
          {
            backgroundColor: config.color + '18',
            borderColor: config.color + '30',
          },
        ]}
      >
        <SpinningIcon
          name={config.icon}
          color={config.color}
          spinning={isSpinning}
        />
      </View>

      {/* Text */}
      <View style={styles.textArea}>
        <Text style={styles.filename} numberOfLines={1}>
          {upload.filename}
        </Text>
        <Text style={[styles.statusText, { color: config.color }]}>
          {upload.error !== undefined ? upload.error : config.label}
        </Text>

        {/* Progress bar — only shown during converting */}
        {(upload.status === 'converting' || upload.status === 'uploading') && (
          <View style={styles.progressTrack}>
            <View
              style={[
                styles.progressFill,
                {
                  width: `${upload.progress}%`,
                  backgroundColor: config.color,
                },
              ]}
            />
          </View>
        )}
      </View>

      {/* Dismiss button on terminal states */}
      {(upload.status === 'ready' || upload.status === 'failed') && (
        <TouchableOpacity
          onPress={() => removeUpload(upload.jobId)}
          hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
        >
          <Ionicons name='close' size={16} color={THEME.colors.text.muted} />
        </TouchableOpacity>
      )}
    </View>
  )
}

// ── Container — renders all active uploads ────────────────────────────────────

export function UploadProgressCard() {
  const activeUploads = useLibraryStore((s) => s.activeUploads)

  if (activeUploads.length === 0) return null

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Ionicons
          name='cloud-upload'
          size={14}
          color={THEME.colors.text.secondary}
        />
        <Text style={styles.headerText}>
          {activeUploads.length === 1
            ? '1 upload in progress'
            : `${activeUploads.length} uploads in progress`}
        </Text>
      </View>

      {activeUploads.map((upload) => (
        <UploadItem key={upload.jobId} upload={upload} />
      ))}
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    marginHorizontal: 16,
    marginBottom: 8,
    backgroundColor: THEME.colors.surface,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    overflow: 'hidden',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: THEME.colors.border.default,
  },
  headerText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 12,
    color: THEME.colors.text.secondary,
  },
  item: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 12,
    gap: 12,
    borderBottomWidth: 1,
    borderBottomColor: THEME.colors.border.default + '80',
  },
  iconWrap: {
    width: 36,
    height: 36,
    borderRadius: 10,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  textArea: {
    flex: 1,
    gap: 3,
  },
  filename: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    color: THEME.colors.text.primary,
  },
  statusText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
  },
  progressTrack: {
    height: 3,
    backgroundColor: THEME.colors.border.light,
    borderRadius: 2,
    overflow: 'hidden',
    marginTop: 4,
  },
  progressFill: {
    height: '100%',
    borderRadius: 2,
  },
})
