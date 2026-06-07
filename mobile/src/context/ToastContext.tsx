import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from 'react'
import {
  Animated,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native'
import { useSafeAreaInsets } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { THEME } from '@/constants/theme'

// ── Types ─────────────────────────────────────────────────────────────────────

export type ToastType = 'success' | 'error' | 'warning' | 'info'

interface ToastItem {
  id: string
  message: string
  type: ToastType
}

interface ToastContextValue {
  show: (message: string, type?: ToastType) => void
}

// ── Context ───────────────────────────────────────────────────────────────────

const ToastContext = createContext<ToastContextValue | null>(null)

// ── Global imperative API ─────────────────────────────────────────────────────

let _globalShow: ((message: string, type?: ToastType) => void) | null = null

export const toast = {
  show: (message: string, type: ToastType = 'info') =>
    _globalShow?.(message, type),
  success: (message: string) => _globalShow?.(message, 'success'),
  error: (message: string) => _globalShow?.(message, 'error'),
  warning: (message: string) => _globalShow?.(message, 'warning'),
  info: (message: string) => _globalShow?.(message, 'info'),
}

// ── Toast config ──────────────────────────────────────────────────────────────

// FIX: Record< was missing the opening angle bracket
const TYPE_CONFIG: Record<
  ToastType,
  { color: string; bg: string; icon: keyof typeof Ionicons.glyphMap }
> = {
  success: {
    color: THEME.colors.success[500],
    bg: THEME.colors.success[500] + '18',
    icon: 'checkmark-circle-outline',
  },
  error: {
    color: THEME.colors.error[500],
    bg: THEME.colors.error[500] + '18',
    icon: 'alert-circle-outline',
  },
  warning: {
    color: THEME.colors.warning[500],
    bg: THEME.colors.warning[500] + '18',
    icon: 'warning-outline',
  },
  info: {
    color: THEME.colors.primary[500],
    bg: THEME.colors.primary[500] + '18',
    icon: 'information-circle-outline',
  },
}

// ── Single toast component ────────────────────────────────────────────────────

function ToastBanner({
  item,
  onDismiss,
}: {
  item: ToastItem
  onDismiss: (id: string) => void
}) {
  const config = TYPE_CONFIG[item.type]
  const slideAnim = useRef(new Animated.Value(-80)).current
  const opacityAnim = useRef(new Animated.Value(0)).current

  useEffect(() => {
    Animated.parallel([
      Animated.spring(slideAnim, {
        toValue: 0,
        friction: 8,
        tension: 120,
        useNativeDriver: true,
      }),
      Animated.timing(opacityAnim, {
        toValue: 1,
        duration: 200,
        useNativeDriver: true,
      }),
    ]).start()

    const timer = setTimeout(() => {
      dismiss()
    }, 3500)

    return () => clearTimeout(timer)
  }, [])

  const dismiss = () => {
    Animated.parallel([
      Animated.timing(slideAnim, {
        toValue: -80,
        duration: 200,
        useNativeDriver: true,
      }),
      Animated.timing(opacityAnim, {
        toValue: 0,
        duration: 200,
        useNativeDriver: true,
      }),
    ]).start(() => onDismiss(item.id))
  }

  return (
    <Animated.View
      style={[
        styles.toast,
        {
          backgroundColor: config.bg,
          borderColor: config.color + '40',
          transform: [{ translateY: slideAnim }],
          opacity: opacityAnim,
        },
      ]}
    >
      <Ionicons name={config.icon} size={18} color={config.color} />
      <Text
        style={[styles.toastText, { color: THEME.colors.text.primary }]}
        numberOfLines={3}
      >
        {item.message}
      </Text>
      <TouchableOpacity
        onPress={dismiss}
        hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
      >
        <Ionicons name='close' size={15} color={THEME.colors.text.muted} />
      </TouchableOpacity>
    </Animated.View>
  )
}

// ── Provider ──────────────────────────────────────────────────────────────────

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const insets = useSafeAreaInsets()
  const [toasts, setToasts] = useState<ToastItem[]>([])
  const counterRef = useRef(0)

  const show = useCallback((message: string, type: ToastType = 'info') => {
    counterRef.current += 1
    const id = `toast_${counterRef.current}`
    setToasts((prev) => [...prev.slice(-2), { id, message, type }])
  }, [])

  const dismiss = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id))
  }, [])

  useEffect(() => {
    _globalShow = show
    return () => {
      _globalShow = null
    }
  }, [show])

  return (
    <ToastContext.Provider value={{ show }}>
      {children}
      <View
        style={[styles.container, { top: insets.top + 12 }]}
        pointerEvents='box-none'
      >
        {toasts.map((item) => (
          <ToastBanner key={item.id} item={item} onDismiss={dismiss} />
        ))}
      </View>
    </ToastContext.Provider>
  )
}

// ── Hook ──────────────────────────────────────────────────────────────────────

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext)
  if (!ctx) throw new Error('useToast must be used inside ToastProvider')
  return ctx
}

// ── Styles ────────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    left: 16,
    right: 16,
    zIndex: 9999,
    gap: 8,
    pointerEvents: 'box-none',
  } as const,
  toast: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 12,
    borderWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 12,
    gap: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  toastText: {
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    lineHeight: 20,
  },
})
