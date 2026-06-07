import React, { useEffect, useRef, useState } from 'react'
import {
  Animated,
  Dimensions,
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  TouchableWithoutFeedback,
  View,
} from 'react-native'
import { useSafeAreaInsets } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { router, usePathname } from 'expo-router'
import { useDrawer } from '@/context/DrawerContext'
import { useAuth } from '@/hooks/useAuth'
import { THEME } from '@/constants/theme'

const SCREEN_WIDTH = Dimensions.get('window').width
const DRAWER_WIDTH = Math.min(SCREEN_WIDTH * 0.82, 320)
const SPRING = { friction: 9, tension: 120, useNativeDriver: true }

type IoniconsName = keyof typeof Ionicons.glyphMap

interface NavItem {
  id: string
  label: string
  icon: IoniconsName
  iconActive: IoniconsName
  route: string
}

const NAV_ITEMS: NavItem[] = [
  {
    id: 'home',
    label: 'Home',
    icon: 'home-outline',
    iconActive: 'home',
    route: '/(tabs)',
  },
  {
    id: 'library',
    label: 'My Library',
    icon: 'library-outline',
    iconActive: 'library',
    route: '/(tabs)/library',
  },
  {
    id: 'discover',
    label: 'Discover',
    icon: 'compass-outline',
    iconActive: 'compass',
    route: '/(tabs)/discover',
  },
  {
    id: 'profile',
    label: 'Profile',
    icon: 'person-outline',
    iconActive: 'person',
    route: '/(tabs)/profile',
  },
]

function InitialsAvatar({ name, color }: { name: string; color: string }) {
  const initials = name
    .split(' ')
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('')
    .slice(0, 2)
  return (
    <View
      style={[
        styles.avatar,
        { backgroundColor: color + '25', borderColor: color + '50' },
      ]}
    >
      <Text style={[styles.avatarText, { color }]}>{initials}</Text>
    </View>
  )
}

export function AppDrawer() {
  const { isOpen, closeDrawer } = useDrawer()
  const { user, logout } = useAuth()
  const insets = useSafeAreaInsets()
  const pathname = usePathname()

  const [modalVisible, setModalVisible] = useState(false)
  const slideAnim = useRef(new Animated.Value(-DRAWER_WIDTH)).current
  const backdropAnim = useRef(new Animated.Value(0)).current

  useEffect(() => {
    if (isOpen) {
      setModalVisible(true)
      Animated.parallel([
        Animated.spring(slideAnim, { toValue: 0, ...SPRING }),
        Animated.timing(backdropAnim, {
          toValue: 1,
          duration: 250,
          useNativeDriver: true,
        }),
      ]).start()
    } else {
      Animated.parallel([
        Animated.spring(slideAnim, { toValue: -DRAWER_WIDTH, ...SPRING }),
        Animated.timing(backdropAnim, {
          toValue: 0,
          duration: 200,
          useNativeDriver: true,
        }),
      ]).start(() => setModalVisible(false))
    }
  }, [isOpen, slideAnim, backdropAnim])

  const navigateTo = (route: string) => {
    closeDrawer()
    setTimeout(
      () => router.push(route as Parameters<typeof router.push>[0]),
      120,
    )
  }

  const isRouteActive = (route: string): boolean => {
    if (route === '/(tabs)') return pathname === '/' || pathname === '/(tabs)'
    return pathname.includes(route.replace('/(tabs)/', ''))
  }

  return (
    <Modal
      visible={modalVisible}
      transparent
      animationType='none'
      statusBarTranslucent
      onRequestClose={closeDrawer}
    >
      <View style={styles.overlay}>
        <TouchableWithoutFeedback onPress={closeDrawer}>
          <Animated.View
            style={[
              styles.backdrop,
              {
                opacity: backdropAnim.interpolate({
                  inputRange: [0, 1],
                  outputRange: [0, 0.65],
                }),
              },
            ]}
          />
        </TouchableWithoutFeedback>

        <Animated.View
          style={[
            styles.drawer,
            { width: DRAWER_WIDTH, transform: [{ translateX: slideAnim }] },
          ]}
        >
          {/* Logo + close */}
          <View style={[styles.drawerHeader, { paddingTop: insets.top + 12 }]}>
            <View style={styles.logoRow}>
              <View style={styles.logoMark}>
                <Ionicons
                  name='book'
                  size={18}
                  color={THEME.colors.primary[500]}
                />
              </View>
              <Text style={styles.logoText}>ReadIn</Text>
            </View>
            <TouchableOpacity
              onPress={closeDrawer}
              style={styles.closeBtn}
              hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
            >
              <Ionicons
                name='close'
                size={22}
                color={THEME.colors.text.secondary}
              />
            </TouchableOpacity>
          </View>

          {/* User card */}
          <View style={styles.userCard}>
            <InitialsAvatar
              name={user?.displayName ?? 'Reader'}
              color={THEME.colors.primary[500]}
            />
            <View style={styles.userInfo}>
              <Text style={styles.userName} numberOfLines={1}>
                {user?.displayName ?? 'Reader'}
              </Text>
              <Text style={styles.userEmail} numberOfLines={1}>
                {user?.email ?? ''}
              </Text>
            </View>
            <View
              style={[
                styles.planBadge,
                {
                  backgroundColor:
                    user?.plan === 'premium'
                      ? THEME.colors.amber[400] + '25'
                      : THEME.colors.border.default,
                  borderColor:
                    user?.plan === 'premium'
                      ? THEME.colors.amber[400] + '60'
                      : THEME.colors.border.light,
                },
              ]}
            >
              <Text
                style={[
                  styles.planText,
                  {
                    color:
                      user?.plan === 'premium'
                        ? THEME.colors.amber[400]
                        : THEME.colors.text.muted,
                  },
                ]}
              >
                {user?.plan === 'premium' ? 'PRO' : 'FREE'}
              </Text>
            </View>
          </View>

          <View style={styles.sep} />

          {/* Nav items */}
          <ScrollView style={{ flex: 1 }} showsVerticalScrollIndicator={false}>
            <Text style={styles.sectionLabel}>MENU</Text>
            {NAV_ITEMS.map((item) => {
              const active = isRouteActive(item.route)
              return (
                <TouchableOpacity
                  key={item.id}
                  onPress={() => navigateTo(item.route)}
                  activeOpacity={0.7}
                  style={[styles.navItem, active && styles.navItemActive]}
                >
                  {active && (
                    <View
                      style={[
                        styles.activeBar,
                        { backgroundColor: THEME.colors.primary[500] },
                      ]}
                    />
                  )}
                  <Ionicons
                    name={active ? item.iconActive : item.icon}
                    size={20}
                    color={
                      active
                        ? THEME.colors.primary[500]
                        : THEME.colors.text.secondary
                    }
                    style={{ marginRight: 14, width: 22, textAlign: 'center' }}
                  />
                  <Text
                    style={[
                      styles.navLabel,
                      {
                        color: active
                          ? THEME.colors.primary[500]
                          : THEME.colors.text.secondary,
                        fontFamily: active
                          ? 'Inter_600SemiBold'
                          : 'Inter_400Regular',
                      },
                    ]}
                  >
                    {item.label}
                  </Text>
                </TouchableOpacity>
              )
            })}

            {user?.plan === 'free' && (
              <>
                <View style={[styles.sep, { marginVertical: 12 }]} />
                <TouchableOpacity
                  style={styles.upgradeCard}
                  activeOpacity={0.8}
                  onPress={() => navigateTo('/(tabs)/profile')}
                >
                  <View style={styles.upgradeIcon}>
                    <Ionicons
                      name='star'
                      size={16}
                      color={THEME.colors.amber[400]}
                    />
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.upgradeTitle}>Upgrade to Premium</Text>
                    <Text style={styles.upgradeSub}>
                      Unlimited books & annotations
                    </Text>
                  </View>
                  <Ionicons
                    name='chevron-forward'
                    size={16}
                    color={THEME.colors.amber[400]}
                  />
                </TouchableOpacity>
              </>
            )}
          </ScrollView>

          {/* Footer */}
          <View
            style={[
              styles.footer,
              { paddingBottom: Math.max(insets.bottom, 16) },
            ]}
          >
            <View style={styles.sep} />
            <TouchableOpacity
              style={styles.footerItem}
              onPress={async () => {
                closeDrawer()
                await logout()
              }}
              activeOpacity={0.7}
            >
              <Ionicons
                name='log-out-outline'
                size={18}
                color={THEME.colors.error[500]}
              />
              <Text
                style={[
                  styles.footerItemText,
                  { color: THEME.colors.error[500] },
                ]}
              >
                Sign Out
              </Text>
            </TouchableOpacity>
            <Text style={styles.version}>ReadIn v1.0.0</Text>
          </View>
        </Animated.View>
      </View>
    </Modal>
  )
}

const styles = StyleSheet.create({
  overlay: { flex: 1, flexDirection: 'row' },
  backdrop: { ...StyleSheet.absoluteFillObject, backgroundColor: '#000' },
  drawer: {
    height: '100%',
    backgroundColor: THEME.colors.surface,
    borderRightWidth: 1,
    borderRightColor: THEME.colors.border.default,
    flexDirection: 'column',
  },
  drawerHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingBottom: 16,
  },
  logoRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  logoMark: {
    width: 34,
    height: 34,
    borderRadius: 10,
    backgroundColor: THEME.colors.primary[500] + '20',
    borderWidth: 1,
    borderColor: THEME.colors.primary[500] + '40',
    alignItems: 'center',
    justifyContent: 'center',
  },
  logoText: {
    fontFamily: 'Inter_700Bold',
    fontSize: 18,
    color: THEME.colors.text.primary,
  },
  closeBtn: {
    width: 34,
    height: 34,
    borderRadius: 10,
    backgroundColor: THEME.colors.elevated,
    alignItems: 'center',
    justifyContent: 'center',
  },
  userCard: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 12,
    gap: 12,
  },
  avatar: {
    width: 46,
    height: 46,
    borderRadius: 23,
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  avatarText: { fontFamily: 'Inter_700Bold', fontSize: 16 },
  userInfo: { flex: 1, gap: 2 },
  userName: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 15,
    color: THEME.colors.text.primary,
  },
  userEmail: {
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: THEME.colors.text.muted,
  },
  planBadge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 6,
    borderWidth: 1,
    flexShrink: 0,
  },
  planText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 10,
    letterSpacing: 0.5,
  },
  sep: {
    height: 1,
    backgroundColor: THEME.colors.border.default,
    marginHorizontal: 20,
  },
  sectionLabel: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 10,
    letterSpacing: 1,
    color: THEME.colors.text.muted,
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 6,
  },
  navItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 13,
    paddingHorizontal: 20,
    position: 'relative',
    marginVertical: 1,
  },
  navItemActive: { backgroundColor: THEME.colors.primary[500] + '10' },
  activeBar: {
    position: 'absolute',
    left: 0,
    top: 8,
    bottom: 8,
    width: 3,
    borderTopRightRadius: 3,
    borderBottomRightRadius: 3,
  },
  navLabel: { fontSize: 15 },
  upgradeCard: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: 16,
    marginVertical: 12,
    padding: 14,
    backgroundColor: THEME.colors.amber[400] + '10',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: THEME.colors.amber[400] + '30',
    gap: 10,
  },
  upgradeIcon: {
    width: 32,
    height: 32,
    borderRadius: 8,
    backgroundColor: THEME.colors.amber[400] + '20',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  upgradeTitle: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 13,
    color: THEME.colors.amber[400],
  },
  upgradeSub: {
    fontFamily: 'Inter_400Regular',
    fontSize: 11,
    color: THEME.colors.amber[400] + '99',
  },
  footer: { paddingHorizontal: 20, paddingTop: 12, gap: 12 },
  footerItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingVertical: 8,
  },
  footerItemText: { fontFamily: 'Inter_500Medium', fontSize: 14 },
  version: {
    fontFamily: 'Inter_400Regular',
    fontSize: 11,
    color: THEME.colors.text.muted,
  },
})
