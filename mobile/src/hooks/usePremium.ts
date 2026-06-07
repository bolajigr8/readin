import { useState, useCallback } from 'react'
import Constants from 'expo-constants'
import { useAuth } from '@/hooks/useAuth'
import { toast } from '@/context/ToastContext'

// ── RevenueCat is not available in Expo Go ────────────────────────────────────
// In a production/development build, replace IS_EXPO_GO guards with real calls.
const IS_EXPO_GO = Constants.executionEnvironment === 'storeClient'

export interface PremiumPackage {
  id: string
  title: string
  price: string
  period: string
  savings?: string
}

export const PREMIUM_PACKAGES: PremiumPackage[] = [
  {
    id: 'premium_monthly',
    title: 'Monthly',
    price: '$4.99',
    period: '/month',
  },
  {
    id: 'premium_annual',
    title: 'Annual',
    price: '$39.99',
    period: '/year',
    savings: 'Save 33%',
  },
]

export const PREMIUM_FEATURES = [
  { label: 'Unlimited books', free: '10 books', premium: 'Unlimited' },
  { label: 'Annotations', free: '20 highlights', premium: 'Unlimited' },
  { label: 'Offline reading', free: '✓', premium: '✓' },
  { label: 'Audio TTS', free: 'Preview only', premium: 'Full chapters' },
  { label: 'Advanced stats', free: '✗', premium: '✓' },
  { label: 'Priority support', free: '✗', premium: '✓' },
]

export function usePremium() {
  const { user } = useAuth()
  const [isPurchasing, setIsPurchasing] = useState(false)
  const [isRestoring, setIsRestoring] = useState(false)

  const isPremium = user?.plan === 'premium'

  // ── Purchase ────────────────────────────────────────────────────────────────
  const purchasePackage = useCallback(
    async (packageId: string): Promise<boolean> => {
      if (IS_EXPO_GO) {
        toast.warning(
          'In-app purchases require a development build. Not available in Expo Go.',
        )
        return false
      }

      setIsPurchasing(true)
      try {
        // ── Real RevenueCat integration (uncomment in production build) ────────
        // const Purchases = require('react-native-purchases').default;
        // const offerings = await Purchases.getOfferings();
        // const pkg = offerings.current?.availablePackages.find(
        //   (p: any) => p.identifier === packageId
        // );
        // if (!pkg) throw new Error('Package not found');
        // const { customerInfo } = await Purchases.purchasePackage(pkg);
        // const isActive = customerInfo.entitlements.active['premium'] !== undefined;
        // return isActive;

        toast.info('Purchase flow available in production build.')
        return false
      } catch (err) {
        if (err instanceof Error && err.message.includes('cancelled')) {
          // User cancelled — not an error
          return false
        }
        toast.error('Purchase failed. Please try again.')
        return false
      } finally {
        setIsPurchasing(false)
      }
    },
    [],
  )

  // ── Restore purchases ────────────────────────────────────────────────────────
  const restorePurchases = useCallback(async (): Promise<boolean> => {
    if (IS_EXPO_GO) {
      toast.warning('Restore requires a development build.')
      return false
    }

    setIsRestoring(true)
    try {
      // const Purchases = require('react-native-purchases').default;
      // const { customerInfo } = await Purchases.restorePurchases();
      // const isActive = customerInfo.entitlements.active['premium'] !== undefined;
      // if (isActive) toast.success("Premium restored!");
      // else toast.info("No active subscription found.");
      // return isActive;

      toast.info('Restore available in production build.')
      return false
    } catch {
      toast.error('Could not restore purchases.')
      return false
    } finally {
      setIsRestoring(false)
    }
  }, [])

  return {
    isPremium,
    isPurchasing,
    isRestoring,
    purchasePackage,
    restorePurchases,
  }
}
