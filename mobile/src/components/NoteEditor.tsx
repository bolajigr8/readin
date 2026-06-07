import React, { useRef, useState } from 'react'
import {
  KeyboardAvoidingView,
  Modal,
  Platform,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native'
import { THEME } from '@/constants/theme'

interface NoteEditorProps {
  isVisible: boolean
  selectedText: string
  initialNote?: string
  onSave: (note: string) => void
  onCancel: () => void
}

export function NoteEditor({
  isVisible,
  selectedText,
  initialNote = '',
  onSave,
  onCancel,
}: NoteEditorProps) {
  const [note, setNote] = useState(initialNote)
  const inputRef = useRef<TextInput>(null)

  const handleSave = () => {
    onSave(note.trim())
    setNote('')
  }

  const handleCancel = () => {
    setNote(initialNote)
    onCancel()
  }

  return (
    <Modal
      visible={isVisible}
      transparent
      animationType='slide'
      onRequestClose={handleCancel}
    >
      <KeyboardAvoidingView
        style={styles.overlay}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <TouchableOpacity
          style={StyleSheet.absoluteFill}
          activeOpacity={1}
          onPress={handleCancel}
        />

        <View style={styles.sheet}>
          {/* Handle */}
          <View style={styles.handle} />

          <Text style={styles.title}>Add Note</Text>

          {/* Selected text */}
          {selectedText.length > 0 && (
            <View style={styles.quoteBox}>
              <View
                style={[
                  styles.quoteLine,
                  { backgroundColor: THEME.colors.primary[500] },
                ]}
              />
              <Text style={styles.quoteText} numberOfLines={3}>
                {selectedText.length > 150
                  ? selectedText.slice(0, 150) + '...'
                  : selectedText}
              </Text>
            </View>
          )}

          {/* Note input */}
          <TextInput
            ref={inputRef}
            style={styles.input}
            placeholder='Add your thoughts...'
            placeholderTextColor={THEME.colors.text.muted}
            value={note}
            onChangeText={setNote}
            multiline
            maxLength={2000}
            autoFocus
            textAlignVertical='top'
          />

          <Text style={styles.charCount}>{note.length} / 2000</Text>

          {/* Actions */}
          <View style={styles.actions}>
            <TouchableOpacity
              style={styles.cancelBtn}
              onPress={handleCancel}
              activeOpacity={0.8}
            >
              <Text style={styles.cancelText}>Cancel</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.saveBtn}
              onPress={handleSave}
              activeOpacity={0.85}
            >
              <Text style={styles.saveText}>Save Note</Text>
            </TouchableOpacity>
          </View>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  )
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: 'rgba(0,0,0,0.5)',
  },
  sheet: {
    backgroundColor: THEME.colors.elevated,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    borderTopWidth: 1,
    borderTopColor: THEME.colors.border.light,
    padding: 24,
    gap: 16,
  },
  handle: {
    width: 36,
    height: 4,
    backgroundColor: THEME.colors.border.light,
    borderRadius: 2,
    alignSelf: 'center',
    marginBottom: 4,
  },
  title: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 17,
    color: THEME.colors.text.primary,
  },
  quoteBox: {
    flexDirection: 'row',
    gap: 10,
    backgroundColor: THEME.colors.surface,
    borderRadius: 8,
    padding: 12,
  },
  quoteLine: {
    width: 3,
    borderRadius: 2,
    flexShrink: 0,
  },
  quoteText: {
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.secondary,
    fontStyle: 'italic',
    lineHeight: 19,
  },
  input: {
    backgroundColor: THEME.colors.surface,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontFamily: 'Inter_400Regular',
    fontSize: 15,
    color: THEME.colors.text.primary,
    minHeight: 100,
    maxHeight: 180,
  },
  charCount: {
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: THEME.colors.text.muted,
    textAlign: 'right',
    marginTop: -8,
  },
  actions: {
    flexDirection: 'row',
    gap: 10,
    paddingBottom: 8,
  },
  cancelBtn: {
    flex: 1,
    paddingVertical: 13,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    backgroundColor: THEME.colors.surface,
    alignItems: 'center',
  },
  cancelText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 15,
    color: THEME.colors.text.secondary,
  },
  saveBtn: {
    flex: 1,
    paddingVertical: 13,
    borderRadius: 12,
    backgroundColor: THEME.colors.primary[500],
    alignItems: 'center',
  },
  saveText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 15,
    color: '#FFFFFF',
  },
})
