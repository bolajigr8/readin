import { Tabs } from 'expo-router'
import { Ionicons } from '@expo/vector-icons'
import { useSafeAreaInsets } from 'react-native-safe-area-context'
import { THEME } from '@/constants/theme'

export default function TabsLayout() {
  const insets = useSafeAreaInsets()

  // ── Universal tab bar height formula ──────────────────────────────────────
  // 56px  = icon (24px) + label (12px) + top/bottom padding (20px)
  // insets.bottom = system navigation area height (device/OS/nav-mode specific)
  // Math.max(..., 0) guards against rare negative inset values
  const TAB_BAR_HEIGHT = 56 + Math.max(insets.bottom, 0)

  return (
    <Tabs
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarActiveTintColor: THEME.colors.primary[500],
        tabBarInactiveTintColor: THEME.colors.text.muted,
        tabBarStyle: {
          backgroundColor: THEME.colors.surface,
          borderTopColor: THEME.colors.border.default,
          borderTopWidth: 1,
          height: TAB_BAR_HEIGHT,
          // Padding bottom pushes icons/labels above the system nav area
          paddingBottom: Math.max(insets.bottom, 6),
          paddingTop: 8,
          // Elevation/shadow for Android
          elevation: 8,
        },
        tabBarLabelStyle: {
          fontFamily: 'Inter_500Medium',
          fontSize: 11,
        },
        tabBarIcon: ({ focused, color, size }) => {
          const iconMap: Record<string, [string, string]> = {
            index: ['home', 'home-outline'],
            library: ['library', 'library-outline'],
            discover: ['compass', 'compass-outline'],
            profile: ['person', 'person-outline'],
          }

          const pair = iconMap[route.name]
          const iconName = (
            focused ? (pair?.[0] ?? 'help') : (pair?.[1] ?? 'help-outline')
          ) as keyof typeof Ionicons.glyphMap

          return <Ionicons name={iconName} size={size} color={color} />
        },
      })}
    >
      <Tabs.Screen name='index' options={{ title: 'Home' }} />
      <Tabs.Screen name='library' options={{ title: 'Library' }} />
      <Tabs.Screen name='discover' options={{ title: 'Discover' }} />
      <Tabs.Screen name='profile' options={{ title: 'Profile' }} />
    </Tabs>
  )
}
