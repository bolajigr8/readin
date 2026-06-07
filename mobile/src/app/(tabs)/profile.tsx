import React, { useState } from 'react'
import {
  Alert,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TouchableOpacity,
  View,
} from 'react-native'
import { SafeAreaView } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { router } from 'expo-router'
import AsyncStorage from '@react-native-async-storage/async-storage'
import { useQuery } from '@tanstack/react-query'

import { AppHeader } from '@/components/AppHeader'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { useAuth } from '@/hooks/useAuth'
import { useSettingsStore } from '@/store/settingsStore'
import { THEME } from '@/constants/theme'
import api from '@/services/api'

interface ReadingStats {
  totalBooks: number
  completedBooks: number
  totalReadingTimeSeconds: number
  averageCompletionRate: number
  annotationCount: number
}

function formatReadingTime(seconds: number): string {
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  if (hours === 0) return `${minutes}m`
  if (minutes === 0) return `${hours}h`
  return `${hours}h ${minutes}m`
}

function SectionHeader({ title }: { title: string }) {
  return <Text style={styles.sectionHeader}>{title}</Text>
}

function SettingsRow({
  icon,
  iconColor,
  label,
  sublabel,
  onPress,
  rightContent,
  isLast = false,
}: {
  icon: keyof typeof Ionicons.glyphMap
  iconColor: string
  label: string
  sublabel?: string
  onPress?: () => void
  rightContent?: React.ReactNode
  isLast?: boolean
}) {
  return (
    <TouchableOpacity
      style={[styles.row, isLast && styles.rowLast]}
      onPress={onPress}
      activeOpacity={onPress !== undefined ? 0.7 : 1}
      disabled={onPress === undefined}
    >
      <View style={[styles.rowIcon, { backgroundColor: iconColor + '20' }]}>
        <Ionicons name={icon} size={18} color={iconColor} />
      </View>
      <View style={styles.rowText}>
        <Text style={styles.rowLabel}>{label}</Text>
        {sublabel !== undefined && (
          <Text style={styles.rowSublabel}>{sublabel}</Text>
        )}
      </View>
      {rightContent !== undefined ? (
        rightContent
      ) : onPress !== undefined ? (
        <Ionicons
          name='chevron-forward'
          size={16}
          color={THEME.colors.text.muted}
        />
      ) : null}
    </TouchableOpacity>
  )
}

export default function ProfileScreen() {
  const { user, logout } = useAuth()
  const settings = useSettingsStore()
  const [showDevTools, setShowDevTools] = useState(false)

  const { data: stats, isLoading: statsLoading } = useQuery({
    queryKey: ['reading-stats'],
    queryFn: async (): Promise<ReadingStats> => {
      const res = await api.get('/progress/stats/me')
      return res.data.data as ReadingStats
    },
    staleTime: 1000 * 60 * 5,
  })

  const isPremium = user?.plan === 'premium'

  const initials = (user?.displayName ?? 'U')
    .split(' ')
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('')
    .slice(0, 2)

  const handleSignOut = () => {
    Alert.alert('Sign Out', 'Are you sure you want to sign out?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Sign Out',
        style: 'destructive',
        onPress: () => void logout(),
      },
    ])
  }

  const handleResetOnboarding = async () => {
    await AsyncStorage.removeItem('@readin/onboarding_complete')
    Alert.alert('Done', 'Restart the app to see onboarding again.')
  }

  return (
    <SafeAreaView
      style={{ flex: 1, backgroundColor: THEME.colors.background }}
      edges={['bottom']}
    >
      <AppHeader title='Profile' />

      <ScrollView showsVerticalScrollIndicator={false}>
        <View style={{ paddingBottom: 40, gap: 24, paddingTop: 16 }}>
          {/* User card */}
          <View style={styles.userCard}>
            <View style={styles.avatarLarge}>
              <Text style={styles.avatarText}>{initials}</Text>
            </View>
            <View style={styles.userInfo}>
              <Text style={styles.userName}>
                {user?.displayName ?? 'Reader'}
              </Text>
              <Text style={styles.userEmail}>{user?.email ?? ''}</Text>
            </View>
            <View
              style={[
                styles.planBadge,
                {
                  backgroundColor: isPremium
                    ? THEME.colors.amber[400] + '20'
                    : THEME.colors.surface,
                  borderColor: isPremium
                    ? THEME.colors.amber[400] + '50'
                    : THEME.colors.border.default,
                },
              ]}
            >
              {isPremium && (
                <Ionicons
                  name='star'
                  size={12}
                  color={THEME.colors.amber[400]}
                />
              )}
              <Text
                style={[
                  styles.planText,
                  {
                    color: isPremium
                      ? THEME.colors.amber[400]
                      : THEME.colors.text.muted,
                  },
                ]}
              >
                {isPremium ? 'Premium' : 'Free Plan'}
              </Text>
            </View>
          </View>

          {/* Reading stats */}
          <View style={styles.section}>
            <SectionHeader title='READING STATS' />
            {statsLoading ? (
              <View style={{ height: 80 }}>
                <LoadingSpinner />
              </View>
            ) : (
              <View style={styles.statsGrid}>
                <View style={styles.statCard}>
                  <Text style={styles.statValue}>{stats?.totalBooks ?? 0}</Text>
                  <Text style={styles.statLabel}>{'Books'}</Text>
                </View>
                <View style={styles.statCard}>
                  <Text style={styles.statValue}>
                    {stats?.completedBooks ?? 0}
                  </Text>
                  <Text style={styles.statLabel}>{'Completed'}</Text>
                </View>
                <View style={styles.statCard}>
                  <Text style={styles.statValue}>
                    {stats !== undefined
                      ? formatReadingTime(stats.totalReadingTimeSeconds)
                      : '0m'}
                  </Text>
                  <Text style={styles.statLabel}>{'Read Time'}</Text>
                </View>
                {/* Last stat card — no right border */}
                <View style={[styles.statCard, { borderRightWidth: 0 }]}>
                  <Text style={styles.statValue}>
                    {stats?.annotationCount ?? 0}
                  </Text>
                  <Text style={styles.statLabel}>{'Highlights'}</Text>
                </View>
              </View>
            )}
          </View>

          {/* Subscription */}
          <View style={styles.section}>
            <SectionHeader title='SUBSCRIPTION' />
            <View style={styles.card}>
              {isPremium ? (
                <SettingsRow
                  icon='star'
                  iconColor={THEME.colors.amber[400]}
                  label='Premium Active'
                  sublabel='Unlimited books, annotations, and more'
                  onPress={() => router.push('/upgrade' as any)}
                  isLast
                />
              ) : (
                <>
                  <SettingsRow
                    icon='flash-outline'
                    iconColor={THEME.colors.primary[500]}
                    label='Upgrade to Premium'
                    sublabel='Unlimited books, annotations, audio and more'
                    onPress={() => router.push('/upgrade' as any)}
                  />
                  <View style={styles.usageBanner}>
                    <Text style={styles.usageText}>
                      {'Free plan: '}
                      <Text style={styles.usageHighlight}>
                        {`${stats?.totalBooks ?? 0} / 10 books`}
                      </Text>
                      {' used'}
                    </Text>
                    <View style={styles.usageTrack}>
                      <View
                        style={[
                          styles.usageFill,
                          {
                            width: `${Math.min(
                              100,
                              ((stats?.totalBooks ?? 0) / 10) * 100,
                            )}%` as `${number}%`,
                          },
                        ]}
                      />
                    </View>
                  </View>
                </>
              )}
            </View>
          </View>

          {/* Reader preferences */}
          <View style={styles.section}>
            <SectionHeader title='READER PREFERENCES' />
            <View style={styles.card}>
              <SettingsRow
                icon='text-outline'
                iconColor={THEME.colors.primary[500]}
                label='Default Font Size'
                sublabel={`${settings.defaultFontSize}px`}
                rightContent={
                  <View style={styles.sizeControl}>
                    <TouchableOpacity
                      onPress={() =>
                        settings.setDefaultFontSize(
                          settings.defaultFontSize - 2,
                        )
                      }
                      disabled={settings.defaultFontSize <= 12}
                    >
                      <Ionicons
                        name='remove-circle-outline'
                        size={20}
                        color={
                          settings.defaultFontSize <= 12
                            ? THEME.colors.text.muted
                            : THEME.colors.primary[500]
                        }
                      />
                    </TouchableOpacity>
                    <Text style={styles.sizeValue}>
                      {settings.defaultFontSize}
                    </Text>
                    <TouchableOpacity
                      onPress={() =>
                        settings.setDefaultFontSize(
                          settings.defaultFontSize + 2,
                        )
                      }
                      disabled={settings.defaultFontSize >= 28}
                    >
                      <Ionicons
                        name='add-circle-outline'
                        size={20}
                        color={
                          settings.defaultFontSize >= 28
                            ? THEME.colors.text.muted
                            : THEME.colors.primary[500]
                        }
                      />
                    </TouchableOpacity>
                  </View>
                }
              />
              <SettingsRow
                icon='color-palette-outline'
                iconColor={THEME.colors.amber[400]}
                label='Default Theme'
                sublabel={
                  settings.defaultReaderTheme.charAt(0).toUpperCase() +
                  settings.defaultReaderTheme.slice(1)
                }
                onPress={() => {
                  const themes = ['light', 'dark', 'sepia'] as const
                  const next =
                    themes[
                      (themes.indexOf(settings.defaultReaderTheme) + 1) %
                        themes.length
                    ] ?? 'dark'
                  settings.setDefaultReaderTheme(next)
                }}
                isLast
              />
            </View>
          </View>

          {/* App settings */}
          <View style={styles.section}>
            <SectionHeader title='APP SETTINGS' />
            <View style={styles.card}>
              <SettingsRow
                icon='notifications-outline'
                iconColor={THEME.colors.primary[400]}
                label='Push Notifications'
                sublabel='Updates about your library'
                rightContent={
                  <Switch
                    value={settings.notificationsEnabled}
                    onValueChange={settings.setNotificationsEnabled}
                    trackColor={{
                      true: THEME.colors.primary[500],
                      false: THEME.colors.border.default,
                    }}
                    thumbColor='#FFFFFF'
                  />
                }
              />
              <SettingsRow
                icon='cloud-download-outline'
                iconColor={THEME.colors.success[500]}
                label='Auto-download EPUBs'
                sublabel='Download when adding to library'
                isLast
                rightContent={
                  <Switch
                    value={settings.autoDownloadEpub}
                    onValueChange={settings.setAutoDownloadEpub}
                    trackColor={{
                      true: THEME.colors.primary[500],
                      false: THEME.colors.border.default,
                    }}
                    thumbColor='#FFFFFF'
                  />
                }
              />
            </View>
          </View>

          {/* Account */}
          <View style={styles.section}>
            <SectionHeader title='ACCOUNT' />
            <View style={styles.card}>
              <SettingsRow
                icon='mail-outline'
                iconColor={THEME.colors.text.muted}
                label='Email'
                sublabel={user?.email ?? ''}
              />
              <SettingsRow
                icon='log-out-outline'
                iconColor={THEME.colors.error[500]}
                label='Sign Out'
                onPress={handleSignOut}
                isLast
              />
            </View>
          </View>

          {/* App info + dev tools */}
          <TouchableOpacity
            style={styles.appInfo}
            onLongPress={() => setShowDevTools((v) => !v)}
            activeOpacity={0.8}
          >
            <Text style={styles.appVersion}>{'ReadIn v1.0.0'}</Text>
            <Text style={styles.appSub}>
              {`Long-press to ${showDevTools ? 'hide' : 'show'} dev tools`}
            </Text>
          </TouchableOpacity>

          {showDevTools && (
            <View style={styles.section}>
              <SectionHeader title='DEVELOPER TOOLS' />
              <View style={styles.card}>
                <SettingsRow
                  icon='refresh-outline'
                  iconColor={THEME.colors.warning[500]}
                  label='Reset Onboarding'
                  sublabel='Restart the app to see it'
                  onPress={() => void handleResetOnboarding()}
                  isLast
                />
              </View>
            </View>
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  userCard: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: 16,
    backgroundColor: THEME.colors.surface,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    padding: 16,
    gap: 14,
  },
  avatarLarge: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: THEME.colors.primary[500] + '25',
    borderWidth: 2,
    borderColor: THEME.colors.primary[500] + '50',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  avatarText: {
    fontFamily: 'Inter_700Bold',
    fontSize: 20,
    color: THEME.colors.primary[500],
  },
  userInfo: { flex: 1, gap: 3 },
  userName: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 16,
    color: THEME.colors.text.primary,
  },
  userEmail: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.muted,
  },
  planBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
    borderWidth: 1,
    flexShrink: 0,
  },
  planText: { fontFamily: 'Inter_600SemiBold', fontSize: 11 },
  section: { gap: 8, paddingHorizontal: 16 },
  sectionHeader: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 11,
    letterSpacing: 0.8,
    color: THEME.colors.text.muted,
  },
  card: {
    backgroundColor: THEME.colors.surface,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    overflow: 'hidden',
  },
  statsGrid: {
    flexDirection: 'row',
    backgroundColor: THEME.colors.surface,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    overflow: 'hidden',
  },
  statCard: {
    flex: 1,
    paddingVertical: 16,
    alignItems: 'center',
    borderRightWidth: 1,
    borderRightColor: THEME.colors.border.default,
    gap: 4,
  },
  statValue: {
    fontFamily: 'Inter_700Bold',
    fontSize: 22,
    color: THEME.colors.primary[500],
  },
  statLabel: {
    fontFamily: 'Inter_400Regular',
    fontSize: 11,
    color: THEME.colors.text.muted,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 14,
    gap: 12,
    borderBottomWidth: 1,
    borderBottomColor: THEME.colors.border.default + '80',
  },
  rowLast: { borderBottomWidth: 0 },
  rowIcon: {
    width: 34,
    height: 34,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  rowText: { flex: 1, gap: 2 },
  rowLabel: {
    fontFamily: 'Inter_400Regular',
    fontSize: 15,
    color: THEME.colors.text.primary,
  },
  rowSublabel: {
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: THEME.colors.text.muted,
  },
  sizeControl: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  sizeValue: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 15,
    color: THEME.colors.text.primary,
    minWidth: 24,
    textAlign: 'center',
  },
  usageBanner: { marginHorizontal: 16, marginBottom: 14, gap: 6 },
  usageText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.secondary,
  },
  usageHighlight: {
    fontFamily: 'Inter_600SemiBold',
    color: THEME.colors.primary[500],
  },
  usageTrack: {
    height: 4,
    backgroundColor: THEME.colors.border.default,
    borderRadius: 2,
    overflow: 'hidden',
  },
  usageFill: {
    height: '100%',
    backgroundColor: THEME.colors.primary[500],
    borderRadius: 2,
  },
  appInfo: { alignItems: 'center', paddingVertical: 8, gap: 4 },
  appVersion: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: THEME.colors.text.muted,
  },
  appSub: {
    fontFamily: 'Inter_400Regular',
    fontSize: 11,
    color: THEME.colors.text.muted + '80',
  },
})
