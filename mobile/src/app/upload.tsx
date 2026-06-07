import React, { useState } from 'react'
import {
  View,
  Text,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  Alert,
} from 'react-native'
import { SafeAreaView } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { router } from 'expo-router'

import { Button } from '@/components/ui/Button'
import { useUpload } from '@/hooks/useUpload'
import { useLibraryStore } from '@/store/libraryStore'
import { THEME } from '@/constants/theme'

// ── Supported formats ─────────────────────────────────────────────────────────

const FORMATS = [
  {
    ext: 'PDF',
    icon: 'document-text-outline' as const,
    note: 'Text-based only',
    color: THEME.colors.error[400],
  },
  {
    ext: 'EPUB',
    icon: 'book-outline' as const,
    note: 'Native ebook',
    color: THEME.colors.primary[500],
  },
  {
    ext: 'DOCX',
    icon: 'document-outline' as const,
    note: 'Word document',
    color: THEME.colors.primary[400],
  },
  {
    ext: 'MOBI',
    icon: 'phone-portrait-outline' as const,
    note: 'Kindle format',
    color: THEME.colors.amber[400],
  },
  {
    ext: 'TXT',
    icon: 'code-outline' as const,
    note: 'Plain text',
    color: THEME.colors.text.secondary,
  },
]

export default function UploadScreen() {
  const { pickAndUpload } = useUpload()
  const activeUploads = useLibraryStore((s) => s.activeUploads)
  const [isLoading, setIsLoading] = useState(false)

  const handleUpload = async () => {
    setIsLoading(true)
    const result = await pickAndUpload()
    setIsLoading(false)

    if (result.success) {
      // Success — close the modal, the UploadProgressCard on Home will show progress
      router.back()
    } else if (result.error !== undefined) {
      // Only show alert for actual errors (not user cancelling picker)
      Alert.alert('Upload Error', result.error)
    }
    // If result.success = false and no error, user just cancelled the picker
  }

  return (
    <SafeAreaView
      style={{ flex: 1, backgroundColor: THEME.colors.background }}
      edges={['top', 'bottom']}
    >
      <ScrollView
        contentContainerStyle={styles.scroll}
        showsVerticalScrollIndicator={false}
      >
        {/* Header */}
        <View style={styles.header}>
          <View>
            <Text style={styles.headerTitle}>Upload a Book</Text>
            <Text style={styles.headerSub}>
              Convert your documents into a beautiful reading experience
            </Text>
          </View>
          <TouchableOpacity
            onPress={() => router.back()}
            style={styles.closeBtn}
          >
            <Ionicons
              name='close'
              size={20}
              color={THEME.colors.text.secondary}
            />
          </TouchableOpacity>
        </View>

        {/* Supported formats grid */}
        <View style={styles.formatsSection}>
          <Text style={styles.sectionLabel}>SUPPORTED FORMATS</Text>
          <View style={styles.formatsGrid}>
            {FORMATS.map((fmt) => (
              <View
                key={fmt.ext}
                style={[styles.formatCard, { borderColor: fmt.color + '35' }]}
              >
                <View
                  style={[
                    styles.formatIcon,
                    { backgroundColor: fmt.color + '18' },
                  ]}
                >
                  <Ionicons name={fmt.icon} size={20} color={fmt.color} />
                </View>
                <Text style={styles.formatExt}>{fmt.ext}</Text>
                <Text style={styles.formatNote}>{fmt.note}</Text>
              </View>
            ))}
          </View>
        </View>

        {/* Warning callout */}
        <View style={styles.callout}>
          <Ionicons
            name='information-circle-outline'
            size={18}
            color={THEME.colors.amber[400]}
          />
          <Text style={styles.calloutText}>
            <Text style={{ fontFamily: 'Inter_600SemiBold' }}>
              Scanned PDFs are not supported.
            </Text>{' '}
            Only text-based PDFs can be converted. If your PDF is an image or
            scan, conversion will fail.
          </Text>
        </View>

        {/* Active uploads indicator */}
        {activeUploads.length > 0 && (
          <View style={styles.activeUploadsNote}>
            <Ionicons
              name='sync-outline'
              size={14}
              color={THEME.colors.primary[500]}
            />
            <Text style={styles.activeUploadsText}>
              {activeUploads.length} upload{activeUploads.length > 1 ? 's' : ''}{' '}
              already in progress
            </Text>
          </View>
        )}

        {/* Upload button */}
        <View style={styles.uploadSection}>
          <TouchableOpacity
            activeOpacity={0.8}
            onPress={handleUpload}
            disabled={isLoading}
            style={[styles.uploadArea, isLoading && { opacity: 0.6 }]}
          >
            <View style={styles.uploadIconWrap}>
              <Ionicons
                name='cloud-upload-outline'
                size={40}
                color={THEME.colors.primary[500]}
              />
            </View>
            <Text style={styles.uploadAreaTitle}>
              {isLoading ? 'Opening picker...' : 'Choose a File'}
            </Text>
            <Text style={styles.uploadAreaSub}>Tap to browse your device</Text>
          </TouchableOpacity>

          <Button
            label={isLoading ? 'Uploading...' : 'Select File to Upload'}
            variant='primary'
            size='lg'
            loading={isLoading}
            onPress={handleUpload}
            className='w-full'
          />
        </View>

        {/* Size limit info */}
        <Text style={styles.sizeNote}>Maximum file size: 100 MB</Text>
      </ScrollView>
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  scroll: {
    padding: 24,
    gap: 28,
    flexGrow: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    gap: 16,
  },
  headerTitle: {
    fontFamily: 'Inter_700Bold',
    fontSize: 26,
    color: THEME.colors.text.primary,
  },
  headerSub: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    color: THEME.colors.text.secondary,
    marginTop: 4,
    lineHeight: 20,
  },
  closeBtn: {
    width: 34,
    height: 34,
    borderRadius: 10,
    backgroundColor: THEME.colors.elevated,
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    marginTop: 4,
  },
  formatsSection: {
    gap: 12,
  },
  sectionLabel: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 11,
    letterSpacing: 1,
    color: THEME.colors.text.muted,
  },
  formatsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  formatCard: {
    width: '28%',
    backgroundColor: THEME.colors.surface,
    borderWidth: 1,
    borderRadius: 10,
    padding: 12,
    alignItems: 'center',
    gap: 6,
  },
  formatIcon: {
    width: 40,
    height: 40,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  formatExt: {
    fontFamily: 'Inter_700Bold',
    fontSize: 13,
    color: THEME.colors.text.primary,
  },
  formatNote: {
    fontFamily: 'Inter_400Regular',
    fontSize: 10,
    color: THEME.colors.text.muted,
    textAlign: 'center',
  },
  callout: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 10,
    backgroundColor: THEME.colors.amber[400] + '12',
    borderWidth: 1,
    borderColor: THEME.colors.amber[400] + '35',
    borderRadius: 10,
    padding: 14,
  },
  calloutText: {
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.secondary,
    lineHeight: 20,
  },
  activeUploadsNote: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: THEME.colors.primary[500] + '10',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  activeUploadsText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.primary[500],
  },
  uploadSection: {
    gap: 16,
  },
  uploadArea: {
    backgroundColor: THEME.colors.surface,
    borderWidth: 2,
    borderColor: THEME.colors.primary[500] + '40',
    borderStyle: 'dashed',
    borderRadius: 16,
    paddingVertical: 32,
    alignItems: 'center',
    gap: 8,
  },
  uploadIconWrap: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: THEME.colors.primary[500] + '15',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 4,
  },
  uploadAreaTitle: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 17,
    color: THEME.colors.text.primary,
  },
  uploadAreaSub: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.secondary,
  },
  sizeNote: {
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: THEME.colors.text.muted,
    textAlign: 'center',
  },
})
