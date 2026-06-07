import React, { useState } from 'react'
import {
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native'
import { SafeAreaView } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { router } from 'expo-router'
import {
  usePremium,
  PREMIUM_PACKAGES,
  PREMIUM_FEATURES,
} from '@/hooks/usePremium'
import { THEME } from '@/constants/theme'

export default function UpgradeScreen() {
  const { purchasePackage, restorePurchases, isPurchasing, isRestoring } =
    usePremium()
  const [selectedPkg, setSelectedPkg] = useState<
    'premium_monthly' | 'premium_annual'
  >('premium_annual')

  const handlePurchase = async () => {
    const success = await purchasePackage(selectedPkg)
    if (success) router.back()
  }

  return (
    <SafeAreaView
      style={{ flex: 1, backgroundColor: THEME.colors.background }}
      edges={['top', 'bottom']}
    >
      {/* Close */}
      <TouchableOpacity
        onPress={() => router.back()}
        style={styles.closeBtn}
        hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
      >
        <Ionicons name='close' size={22} color={THEME.colors.text.secondary} />
      </TouchableOpacity>

      <ScrollView showsVerticalScrollIndicator={false}>
        <View style={{ padding: 24, gap: 28, paddingBottom: 16 }}>
          {/* Hero */}
          <View style={styles.hero}>
            <View style={styles.heroIcon}>
              <Ionicons name='star' size={36} color={THEME.colors.amber[400]} />
            </View>
            <Text style={styles.heroTitle}>ReadIn Premium</Text>
            <Text style={styles.heroSub}>
              Unlock the full reading experience with unlimited books,
              highlights, and audio.
            </Text>
          </View>

          {/* Feature comparison */}
          <View style={styles.featuresCard}>
            <View style={styles.featureHeader}>
              <Text style={styles.featureHeaderLabel} />
              <Text style={[styles.featureCol, styles.featureColLabel]}>
                Free
              </Text>
              <Text
                style={[
                  styles.featureCol,
                  styles.featureColLabel,
                  { color: THEME.colors.amber[400] },
                ]}
              >
                Premium
              </Text>
            </View>
            <View style={styles.featureDivider} />
            {PREMIUM_FEATURES.map((f, i) => (
              <View
                key={f.label}
                style={[
                  styles.featureRow,
                  i === PREMIUM_FEATURES.length - 1 && styles.featureRowLast,
                ]}
              >
                <Text style={styles.featureLabel}>{f.label}</Text>
                <Text style={styles.featureCol}>{f.free}</Text>
                <Text
                  style={[
                    styles.featureCol,
                    { color: THEME.colors.success[400] },
                  ]}
                >
                  {f.premium}
                </Text>
              </View>
            ))}
          </View>

          {/* Package selection */}
          <View style={styles.packages}>
            {PREMIUM_PACKAGES.map((pkg) => {
              const isSelected = selectedPkg === pkg.id
              return (
                <TouchableOpacity
                  key={pkg.id}
                  onPress={() =>
                    setSelectedPkg(
                      pkg.id as 'premium_monthly' | 'premium_annual',
                    )
                  }
                  style={[styles.pkgCard, isSelected && styles.pkgCardSelected]}
                  activeOpacity={0.8}
                >
                  {/* Best value badge */}
                  {pkg.savings !== undefined && (
                    <View style={styles.savingsBadge}>
                      <Text style={styles.savingsText}>{pkg.savings}</Text>
                    </View>
                  )}

                  <View style={styles.pkgLeft}>
                    <View
                      style={[
                        styles.pkgRadio,
                        isSelected && styles.pkgRadioSelected,
                      ]}
                    >
                      {isSelected && <View style={styles.pkgRadioDot} />}
                    </View>
                    <View>
                      <Text style={styles.pkgTitle}>{pkg.title}</Text>
                      <Text style={styles.pkgPeriod}>{pkg.period}</Text>
                    </View>
                  </View>

                  <Text
                    style={[
                      styles.pkgPrice,
                      isSelected && { color: THEME.colors.amber[400] },
                    ]}
                  >
                    {pkg.price}
                  </Text>
                </TouchableOpacity>
              )
            })}
          </View>

          {/* Subscribe button */}
          <TouchableOpacity
            style={[styles.subscribeBtn, isPurchasing && { opacity: 0.7 }]}
            onPress={handlePurchase}
            disabled={isPurchasing}
            activeOpacity={0.85}
          >
            <Ionicons name='star' size={18} color='#000000' />
            <Text style={styles.subscribeBtnText}>
              {isPurchasing ? 'Processing...' : 'Start Premium'}
            </Text>
          </TouchableOpacity>

          {/* Restore */}
          <TouchableOpacity
            onPress={() => void restorePurchases()}
            disabled={isRestoring}
            style={styles.restoreBtn}
          >
            <Text style={styles.restoreBtnText}>
              {isRestoring ? 'Restoring...' : 'Restore Purchases'}
            </Text>
          </TouchableOpacity>

          {/* Legal */}
          <Text style={styles.legal}>
            Subscription auto-renews. Cancel any time in your App Store or
            Google Play account settings. By subscribing you agree to our Terms
            of Service and Privacy Policy.
          </Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  closeBtn: {
    position: 'absolute',
    top: 54,
    right: 20,
    zIndex: 10,
    width: 34,
    height: 34,
    borderRadius: 10,
    backgroundColor: THEME.colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
  },
  hero: {
    alignItems: 'center',
    paddingTop: 40,
    gap: 12,
  },
  heroIcon: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: THEME.colors.amber[400] + '20',
    borderWidth: 2,
    borderColor: THEME.colors.amber[400] + '40',
    alignItems: 'center',
    justifyContent: 'center',
  },
  heroTitle: {
    fontFamily: 'Inter_700Bold',
    fontSize: 28,
    color: THEME.colors.text.primary,
  },
  heroSub: {
    fontFamily: 'Inter_400Regular',
    fontSize: 15,
    color: THEME.colors.text.secondary,
    textAlign: 'center',
    lineHeight: 22,
  },
  featuresCard: {
    backgroundColor: THEME.colors.surface,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: THEME.colors.border.default,
    overflow: 'hidden',
  },
  featureHeader: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingVertical: 10,
    backgroundColor: THEME.colors.elevated,
  },
  featureHeaderLabel: { flex: 1 },
  featureCol: {
    width: 80,
    textAlign: 'center',
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: THEME.colors.text.muted,
  },
  featureColLabel: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 13,
    color: THEME.colors.text.secondary,
  },
  featureDivider: {
    height: 1,
    backgroundColor: THEME.colors.border.default,
  },
  featureRow: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingVertical: 12,
    alignItems: 'center',
    borderBottomWidth: 1,
    borderBottomColor: THEME.colors.border.default + '60',
  },
  featureRowLast: { borderBottomWidth: 0 },
  featureLabel: {
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    color: THEME.colors.text.primary,
  },
  packages: { gap: 12 },
  pkgCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: THEME.colors.surface,
    borderRadius: 14,
    borderWidth: 1.5,
    borderColor: THEME.colors.border.default,
    padding: 16,
    position: 'relative',
  },
  pkgCardSelected: {
    borderColor: THEME.colors.amber[400],
    backgroundColor: THEME.colors.amber[400] + '08',
  },
  savingsBadge: {
    position: 'absolute',
    top: -10,
    right: 16,
    backgroundColor: THEME.colors.amber[400],
    paddingHorizontal: 10,
    paddingVertical: 3,
    borderRadius: 20,
  },
  savingsText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 11,
    color: '#000000',
  },
  pkgLeft: { flexDirection: 'row', alignItems: 'center', gap: 12, flex: 1 },
  pkgRadio: {
    width: 20,
    height: 20,
    borderRadius: 10,
    borderWidth: 2,
    borderColor: THEME.colors.border.light,
    alignItems: 'center',
    justifyContent: 'center',
  },
  pkgRadioSelected: { borderColor: THEME.colors.amber[400] },
  pkgRadioDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: THEME.colors.amber[400],
  },
  pkgTitle: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 15,
    color: THEME.colors.text.primary,
  },
  pkgPeriod: {
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: THEME.colors.text.muted,
  },
  pkgPrice: {
    fontFamily: 'Inter_700Bold',
    fontSize: 20,
    color: THEME.colors.text.primary,
  },
  subscribeBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    backgroundColor: THEME.colors.amber[400],
    borderRadius: 14,
    paddingVertical: 16,
  },
  subscribeBtnText: {
    fontFamily: 'Inter_700Bold',
    fontSize: 17,
    color: '#000000',
  },
  restoreBtn: {
    alignItems: 'center',
    paddingVertical: 8,
    marginTop: -12,
  },
  restoreBtnText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    color: THEME.colors.text.muted,
    textDecorationLine: 'underline',
  },
  legal: {
    fontFamily: 'Inter_400Regular',
    fontSize: 11,
    color: THEME.colors.text.muted,
    textAlign: 'center',
    lineHeight: 17,
  },
})
